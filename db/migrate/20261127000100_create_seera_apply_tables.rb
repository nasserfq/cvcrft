# Seera Apply (packs/job_applications). Only new tables, so it rolls back cleanly.
class CreateSeeraApplyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :apply_employers do |t|
      t.string :name, null: false
      t.string :ats, null: false
      t.string :identifier, null: false
      t.string :host
      t.string :site
      t.string :country
      t.boolean :verified, null: false, default: false
      t.boolean :active, null: false, default: true
      t.datetime :last_fetched_at
      t.text :last_error
      t.timestamps
    end
    add_index :apply_employers, [ :ats, :identifier ], unique: true

    create_table :apply_postings do |t|
      t.references :employer, null: false, foreign_key: { to_table: :apply_employers, on_delete: :cascade }
      t.string :external_id, null: false
      t.string :title, null: false
      t.string :url, null: false
      t.string :apply_url, null: false
      t.string :location
      t.string :country
      t.string :city
      t.text :description
      t.datetime :posted_at
      t.datetime :fetched_at, null: false
      t.datetime :closed_at
      t.timestamps
    end
    add_index :apply_postings, [ :employer_id, :external_id ], unique: true
    add_index :apply_postings, [ :city, :closed_at ]
    add_index :apply_postings, :posted_at

    create_table :apply_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :titles, array: true, null: false, default: []
      t.string :cities, array: true, null: false, default: []
      t.timestamps
    end

    create_table :apply_matches do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :posting, null: false, foreign_key: { to_table: :apply_postings, on_delete: :cascade }
      t.integer :score, null: false
      t.text :score_reason
      t.timestamps
    end
    add_index :apply_matches, [ :user_id, :posting_id ], unique: true
    add_index :apply_matches, [ :user_id, :score ]

    create_table :apply_ai_usages do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.integer :scores, null: false, default: 0
      t.timestamps
    end
    add_index :apply_ai_usages, [ :user_id, :day ], unique: true
  end
end
