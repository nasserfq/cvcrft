class CreateCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.text :description
      t.integer :bonus_summary_translations, null: false, default: 0
      t.integer :bonus_jobs_translations, null: false, default: 0
      t.integer :bonus_cv_builder_generations, null: false, default: 0
      t.integer :bonus_job_based_generations, null: false, default: 0
      t.datetime :expires_at
      t.integer :max_redemptions
      t.integer :redemptions_count, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :coupons, "lower(code)", unique: true, name: "index_coupons_on_lower_code"

    create_table :coupon_redemptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :coupon, null: false, foreign_key: true
      t.datetime :redeemed_at, null: false

      t.timestamps
    end

    add_index :coupon_redemptions, [ :user_id, :coupon_id ], unique: true
  end
end
