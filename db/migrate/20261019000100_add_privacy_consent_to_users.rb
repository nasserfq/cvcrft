class AddPrivacyConsentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :privacy_accepted_at, :datetime
    add_column :users, :privacy_policy_version, :string
  end
end
