require "aws-sdk-ses"

class SendOtpEmailJob < ApplicationJob
  queue_as :default

  def perform(email, otp_code)
    Rails.logger.info "Sending OTP email to #{email}"

    ses_service = AmazonSesService.new
    subject = "Your CV Craft Login Code"
    body = generate_otp_email_body(otp_code)

    ses_service.send_email(to: email, subject: subject, body: body)
    Rails.logger.info "OTP email sent successfully to #{email}"
  rescue => e
    Rails.logger.error "Error in SendOtpEmailJob: #{e.message}"
    raise e
  end

  private

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
            <p>Your Login Verification Code</p>
          </div>
          <div class="content">
            <h2>Hello!</h2>
            <p>You requested a login code for your CV Craft account. Use the code below to complete your login:</p>
      #{'      '}
            <div class="otp-code">#{otp_code}</div>
      #{'      '}
            <p><strong>This code will expire in 10 minutes.</strong></p>
      #{'      '}
            <p>If you didn't request this code, please ignore this email.</p>
      #{'      '}
            <p>Best regards,<br>The CV Craft Team</p>
          </div>
          <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    HTML
  end
end
