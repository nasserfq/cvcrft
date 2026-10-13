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

  def send_welcome_email(email_data, options)
    ses_service = AmazonSesService.new

    subject = "Welcome to CV Craft!"
    body = generate_welcome_email_body(email_data[:name] || "User")

    ses_service.send_email(
      to: email_data[:email],
      subject: subject,
      body: body
    )
  end

  def send_notification_email(email_data, options)
    ses_service = AmazonSesService.new

    subject = options[:subject] || "CV Craft Notification"
    body = options[:body] || "You have a new notification from CV Craft."

    ses_service.send_email(
      to: email_data[:email],
      subject: subject,
      body: body
    )
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
