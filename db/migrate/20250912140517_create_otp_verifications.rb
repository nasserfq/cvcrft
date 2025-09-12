class CreateOtpVerifications < ActiveRecord::Migration[8.0]
  def change
    create_table :otp_verifications do |t|
      t.string :email, null: false
      t.string :otp_code, null: false
      t.datetime :expires_at, null: false
      t.boolean :verified, default: false

      t.timestamps
    end
    
    add_index :otp_verifications, :email
    add_index :otp_verifications, :otp_code
    add_index :otp_verifications, :expires_at
  end
end
