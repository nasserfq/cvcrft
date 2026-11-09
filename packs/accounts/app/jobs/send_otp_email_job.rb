class SendOtpEmailJob < ApplicationJob
  queue_as :default

  self.log_arguments = false

  # Takes the OtpVerification id, not the code, so the login secret never sits
  # in Redis, the Sidekiq dashboard or an error report's job arguments.
  def perform(otp_verification_id)
    # Replaced by a newer code, already used, expired or burned before this
    # ran (e.g. after queue delays or retries): sending it would only confuse.
    otp = OtpVerification.valid.find_by(id: otp_verification_id)
    return unless otp

    Rails.logger.info "Sending OTP email (otp_verification_id=#{otp.id})"

    SeeraEmail.otp(otp.otp_code).deliver_to(otp.email)
    Rails.logger.info "OTP email sent (otp_verification_id=#{otp.id})"
  rescue => e
    Rails.logger.error "Error in SendOtpEmailJob: #{e.message}"
    raise e
  end
end
