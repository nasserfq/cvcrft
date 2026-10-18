class OtpVerification < ApplicationRecord
  # Wrong guesses allowed against one code before it is burned. With a
  # 6-digit code this keeps the odds of guessing it at 5 in a million.
  MAX_FAILED_ATTEMPTS = 5

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :otp_code, presence: true, length: { is: 6 }
  validates :expires_at, presence: true

  scope :valid, -> { where("expires_at > ?", Time.current).where(verified: false).where("failed_attempts < ?", MAX_FAILED_ATTEMPTS) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  # Checks a submitted code. Every guess takes an attempt in the database
  # before the compare, so parallel requests can't each slip past the cap;
  # a right code consumes it atomically, so it cannot sign in twice.
  def verify!(code)
    return false if expired? || verified?

    reserved = self.class.where(id: id).where("failed_attempts < ?", MAX_FAILED_ATTEMPTS)
                         .update_all("failed_attempts = failed_attempts + 1")
    return false if reserved.zero?
    return false unless ActiveSupport::SecurityUtils.secure_compare(otp_code, code.to_s)

    self.class.where(id: id, verified: false).update_all(verified: true, updated_at: Time.current) == 1
  end

  def self.generate_for(email)
    # Clean up old OTPs for this email
    where(email: email).destroy_all

    # Generate new OTP
    otp_code = SecureRandom.random_number(1000000).to_s.rjust(6, "0")
    expires_at = 10.minutes.from_now

    create!(
      email: email,
      otp_code: otp_code,
      expires_at: expires_at
    )
  end
end
