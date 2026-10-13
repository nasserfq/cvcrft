class AddFailedAttemptsToOtpVerifications < ActiveRecord::Migration[8.0]
  def change
    add_column :otp_verifications, :failed_attempts, :integer, default: 0, null: false
  end
end
