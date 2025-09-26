class EmailLoadTestJob < ApplicationJob
  queue_as :default
  
  def perform(total_users, batch_size, email_type)
    Rails.logger.info "Starting email load test: #{total_users} users, batch size: #{batch_size}, type: #{email_type}"
    
    start_time = Time.current
    successful_sends = 0
    failed_sends = 0
    
    # Create test users if needed
    create_test_users_if_needed(total_users)
    
    # Process users in batches
    User.limit(total_users).find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|
      batch_start_time = Time.current
      
      Rails.logger.info "Processing batch #{batch_index + 1}/#{(total_users / batch_size).ceil} (#{batch.size} users)"
      
      # Prepare email data for this batch
      email_data = batch.map do |user|
        {
          email: user.email,
          name: user.email.split('@').first,
          otp_code: generate_otp_code
        }
      end
      
      # Send batch emails
      begin
        BatchEmailService.perform_async(email_data, email_type)
        successful_sends += batch.size
        Rails.logger.info "Enqueued batch #{batch_index + 1} for processing"
      rescue => e
        Rails.logger.error "Failed to enqueue batch #{batch_index + 1}: #{e.message}"
        failed_sends += batch.size
      end
      
      batch_duration = Time.current - batch_start_time
      Rails.logger.info "Batch #{batch_index + 1} processed in #{batch_duration.round(2)}s"
      
      # Small delay between batches to avoid overwhelming the system
      sleep(0.5) unless batch_index == (total_users / batch_size).ceil - 1
    end
    
    total_duration = Time.current - start_time
    
    # Store results
    results = {
      total_users: total_users,
      successful_enqueues: successful_sends,
      failed_enqueues: failed_sends,
      duration: total_duration,
      completed_at: Time.current,
      email_type: email_type
    }
    
    Rails.cache.write("load_test_results_#{self.job_id}", results, expires_in: 24.hours)
    
    Rails.logger.info "Load test completed:"
    Rails.logger.info "  Total duration: #{total_duration.round(2)}s"
    Rails.logger.info "  Successful enqueues: #{successful_sends}"
    Rails.logger.info "  Failed enqueues: #{failed_sends}"
    Rails.logger.info "  Success rate: #{(successful_sends.to_f / total_users * 100).round(2)}%"
    
    results
  end
  
  private
  
  def create_test_users_if_needed(total_users)
    current_test_users = User.where("email LIKE ?", "%test%").count
    
    if current_test_users < total_users
      users_to_create = total_users - current_test_users
      Rails.logger.info "Creating #{users_to_create} test users"
      
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
