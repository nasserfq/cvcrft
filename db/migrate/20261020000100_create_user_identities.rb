# Social sign-in accounts (Google, Apple, LinkedIn) linked to a user. Apple
# sends the email only on the first login, so later logins match on uid.
class CreateUserIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.timestamps
    end
    add_index :user_identities, [ :provider, :uid ], unique: true
  end
end
