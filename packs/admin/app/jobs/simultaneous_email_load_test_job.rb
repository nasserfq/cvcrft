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
    ses_service = AmazonSesService.new
    otp_code = email_data[:otp_code] || generate_otp_code

    subject = "Your CV Craft Login Code"
    body = generate_otp_email_body(otp_code)

    ses_service.send_email(
      to: email_data[:email],
      subject: subject,
      body: body
    )
  end

  def send_welcome_email_direct(email_data)
    ses_service = AmazonSesService.new

    subject = "Welcome to CV Craft!"
    body = generate_welcome_email_body(email_data[:name] || "User")

    ses_service.send_email(
      to: email_data[:email],
      subject: subject,
      body: body
    )
  end

  def send_notification_email_direct(email_data)
    ses_service = AmazonSesService.new

    subject = "CV Craft Notification"
    body = "You have a new notification from CV Craft."

    ses_service.send_email(
      to: email_data[:email],
      subject: subject,
      body: body
    )
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

  def generate_otp_email_body(otp_code)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Your Login Code</title>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #10b981; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }
          .otp-code { font-size: 32px; font-weight: bold; color: #10b981; text-align: center; margin: 20px 0; padding: 20px; background: white; border-radius: 8px; letter-spacing: 4px; }
          .footer { text-align: center; margin-top: 20px; color: #6b7280; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>CV Craft</h1>
          </div>
          <div class="content">
            <h2>Your Login Code</h2>
            <p>Use the following code to log in to your CV Craft account:</p>
            <div class="otp-code">#{otp_code}</div>
            <p>This code will expire in 10 minutes for security reasons.</p>
            <p>If you didn't request this code, please ignore this email.</p>
          </div>
          <div class="footer">
            <p>&copy; 2024 CV Craft. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    HTML
  end

  def generate_welcome_email_body(name)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to CV Craft</title>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #10b981; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: #f9fafb; padding: 30px; border-radius: 0 0 8px 8px; }
          .footer { text-align: center; margin-top: 20px; color: #6b7280; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Welcome to CV Craft!</h1>
          </div>
          <div class="content">
            <h2>Hello #{name}!</h2>
            <p>Welcome to CV Craft, the ultimate platform for creating professional resumes and CVs.</p>
            <p>Get started by:</p>
            <ul>
              <li>Creating your first resume</li>
              <li>Adding your work experience</li>
              <li>Including your skills and education</li>
              <li>Generating a professional PDF</li>
            </ul>
            <p>If you have any questions, feel free to reach out to our support team.</p>
          </div>
          <div class="footer">
            <p>&copy; 2024 CV Craft. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    HTML
  end
end
