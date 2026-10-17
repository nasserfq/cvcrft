class AddUniqueIndexToUsersEmail < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # OTP login uses find_or_create_by(email:); without this, two parallel
    # logins can create duplicate accounts. Fails if duplicates already exist.
    add_index :users, :email, unique: true, algorithm: :concurrently
  end
end
