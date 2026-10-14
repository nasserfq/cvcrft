class BatchEmailService
  include Sidekiq::Worker

  sidekiq_options queue: :mailers, retry: 3, backtrace: true

  def perform(user_emails, email_type = "otp", options = {})
    Rails.logger.info "Starting batch email processing for #{user_emails.size} users"

    start_time = Time.current
    successful_sends = 0
    failed_sends = 0

    # Process emails in smaller chunks to avoid overwhelming SES
    chunk_size = ENV.fetch("EMAIL_CHUNK_SIZE", 50).to_i
    delay_between_chunks = ENV.fetch("EMAIL_CHUNK_DELAY", 0.1).to_f

    user_emails.each_slice(chunk_size) do |chunk|
      chunk_start_time = Time.current

      # Process chunk in parallel
      results = chunk.map do |email_data|
        send_single_email(email_data, email_type, options)
      end

      # Count results
      successful_sends += results.count { |r| r[:success] }
      failed_sends += results.count { |r| !r[:success] }

      chunk_duration = Time.current - chunk_start_time
      Rails.logger.info "Processed chunk of #{chunk.size} emails in #{chunk_duration.round(2)}s"

      # Delay between chunks to respect rate limits
      sleep(delay_between_chunks) if delay_between_chunks > 0
    end

    total_duration = Time.current - start_time

    Rails.logger.info "Batch email processing completed:"
    Rails.logger.info "  Total duration: #{total_duration.round(2)}s"
    Rails.logger.info "  Successful: #{successful_sends}"
    Rails.logger.info "  Failed: #{failed_sends}"
    Rails.logger.info "  Success rate: #{(successful_sends.to_f / user_emails.size * 100).round(2)}%"

    # Store results in cache for monitoring
    Rails.cache.write("batch_email_results_#{self.jid}", {
      total: user_emails.size,
      successful: successful_sends,
      failed: failed_sends,
      duration: total_duration,
      completed_at: Time.current
    }, expires_in: 1.hour)

    { successful: successful_sends, failed: failed_sends, duration: total_duration }
  end

  private

  def send_single_email(email_data, email_type, options)
    begin
      case email_type
      when "otp"
        send_otp_email(email_data, options)
      when "welcome"
        send_welcome_email(email_data, options)
      when "notification"
        send_notification_email(email_data, options)
      else
        raise ArgumentError, "Unknown email type: #{email_type}"
      end

      { success: true, email: email_data[:email] }
    rescue => e
      Rails.logger.error "Failed to send email to #{email_data[:email]}: #{e.message}"
      { success: false, email: email_data[:email], error: e.message }
    end
  end

  def send_otp_email(email_data, options)
    otp_code = email_data[:otp_code] || generate_otp_code
    SeeraEmail.otp(otp_code).deliver_to(email_data[:email])
  end

  def send_welcome_email(email_data, options)
    SeeraEmail.welcome(email_data[:name] || email_data[:email].split("@").first).deliver_to(email_data[:email])
  end

  def send_notification_email(email_data, options)
    SeeraEmail.notification.deliver_to(email_data[:email])
  end

  def generate_otp_code
    rand(100000..999999).to_s
  end
end
