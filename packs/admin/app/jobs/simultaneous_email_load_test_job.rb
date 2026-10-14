class SimultaneousEmailLoadTestJob < ApplicationJob
  queue_as :default

  def perform(total_users, email_type)
    Rails.logger.info "Starting SIMULTANEOUS email load test: #{total_users} users, type: #{email_type}"

    start_time = Time.current
    successful_sends = 0
    failed_sends = 0

    # Create test users if needed
    create_test_users_if_needed(total_users)

    # Get all users at once
    users = User.limit(total_users).to_a
    Rails.logger.info "Processing #{users.size} users simultaneously"

    # Prepare all email data
    email_data = users.map do |user|
      {
        email: user.email,
        name: user.email.split("@").first,
        otp_code: generate_otp_code
      }
    end

    # Process ALL emails simultaneously using parallel processing
    results = process_emails_simultaneously(email_data, email_type)

    # Count results
    successful_sends = results.count { |r| r[:success] }
    failed_sends = results.count { |r| !r[:success] }

    total_duration = Time.current - start_time

    # Store results
    results_data = {
      total_users: total_users,
      successful_sends: successful_sends,
      failed_sends: failed_sends,
      duration: total_duration,
      completed_at: Time.current,
      email_type: email_type,
      simultaneous: true
    }

    Rails.cache.write("simultaneous_load_test_results_#{self.job_id}", results_data, expires_in: 24.hours)

    Rails.logger.info "SIMULTANEOUS load test completed:"
    Rails.logger.info "  Total duration: #{total_duration.round(2)}s"
    Rails.logger.info "  Successful sends: #{successful_sends}"
    Rails.logger.info "  Failed sends: #{failed_sends}"
    Rails.logger.info "  Success rate: #{(successful_sends.to_f / total_users * 100).round(2)}%"
    Rails.logger.info "  Emails per second: #{(total_users / total_duration).round(2)}"

    results_data
  end

  private

  def process_emails_simultaneously(email_data, email_type)
    # Use parallel processing to send all emails at once
    # This will create a massive burst of concurrent requests

    # Split into chunks for better memory management
    chunk_size = 1000
    all_results = []

    email_data.each_slice(chunk_size) do |chunk|
      # Process each chunk in parallel
      chunk_results = Parallel.map(chunk, in_threads: 50) do |email_data_item|
        send_single_email_immediately(email_data_item, email_type)
      end

      all_results.concat(chunk_results)

      # Small delay between chunks to avoid overwhelming the system
      sleep(0.1)
    end

    all_results
  end

  def send_single_email_immediately(email_data, email_type)
    begin
      case email_type
      when "otp"
        send_otp_email_direct(email_data)
      when "welcome"
        send_welcome_email_direct(email_data)
      when "notification"
        send_notification_email_direct(email_data)
      else
        raise ArgumentError, "Unknown email type: #{email_type}"
      end

      { success: true, email: email_data[:email] }
    rescue => e
      Rails.logger.error "Failed to send email to #{email_data[:email]}: #{e.message}"
      { success: false, email: email_data[:email], error: e.message }
    end
  end

  def send_otp_email_direct(email_data)
    otp_code = email_data[:otp_code] || generate_otp_code
    SeeraEmail.otp(otp_code).deliver_to(email_data[:email])
  end

  def send_welcome_email_direct(email_data)
    SeeraEmail.welcome(email_data[:name] || email_data[:email].split("@").first).deliver_to(email_data[:email])
  end

  def send_notification_email_direct(email_data)
    SeeraEmail.notification.deliver_to(email_data[:email])
  end

  def create_test_users_if_needed(total_users)
    current_test_users = User.where("email LIKE ?", "%test%").count

    if current_test_users < total_users
      users_to_create = total_users - current_test_users
      Rails.logger.info "Creating #{users_to_create} test users"

      # Create users in batches to avoid memory issues
      users_to_create.times do |i|
        User.create!(
          email: "test_user_#{current_test_users + i + 1}@example.com",
          created_at: Time.current,
          updated_at: Time.current
        )

        # Show progress every 1000 users
        if (i + 1) % 1000 == 0
          Rails.logger.info "Created #{i + 1} test users..."
        end
      end

      Rails.logger.info "Created #{users_to_create} test users"
    end
  end

  def generate_otp_code
    rand(100000..999999).to_s
  end
end
