class OtpVerification < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :otp_code, presence: true, length: { is: 6 }
  validates :expires_at, presence: true

  scope :valid, -> { where("expires_at > ?", Time.current).where(verified: false) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def verify!(code)
    return false if expired? || verified?
    return false unless otp_code == code

    update!(verified: true)
    true
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
