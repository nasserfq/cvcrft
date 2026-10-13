# Credits for AI features (the coach first). The ledger is append-only: every
# grant and spend is one row, and users.credit_balance is the running total,
# updated under the user's row lock in the same transaction.
class CreateBillingTables < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :credit_balance, :integer, default: 0, null: false

    create_table :credit_ledger_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.integer :balance_after, null: false
      t.string :reason, null: false
      # One row per real-world event (a purchase, a coupon, a coach message),
      # so retries and double callbacks can't grant or charge twice.
      t.string :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :credit_ledger_entries, :idempotency_key, unique: true
    add_index :credit_ledger_entries, [ :user_id, :created_at ]

    create_table :credit_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.string :pack, null: false
      t.integer :credits, null: false
      t.integer :amount_halalas, null: false
      t.string :currency, null: false, default: "SAR"
      t.string :status, null: false, default: "pending"
      t.string :moyasar_invoice_id
      t.string :checkout_url
      t.datetime :paid_at

      t.timestamps
    end
    add_index :credit_purchases, :moyasar_invoice_id, unique: true
  end
end
