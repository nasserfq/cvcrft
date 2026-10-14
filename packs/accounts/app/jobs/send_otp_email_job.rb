class SendOtpEmailJob < ApplicationJob
  queue_as :default

  # The code is a login secret: keep it out of the job log lines.
  self.log_arguments = false

  def perform(email, otp_code)
    Rails.logger.info "Sending OTP email to #{email}"

    SeeraEmail.otp(otp_code).deliver_to(email)
    Rails.logger.info "OTP email sent successfully to #{email}"
  rescue => e
    Rails.logger.error "Error in SendOtpEmailJob: #{e.message}"
    raise e
  end
end
