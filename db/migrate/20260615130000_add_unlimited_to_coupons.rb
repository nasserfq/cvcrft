class AddUnlimitedToCoupons < ActiveRecord::Migration[8.0]
  def change
    add_column :coupons, :unlimited, :boolean, null: false, default: false
  end
end
