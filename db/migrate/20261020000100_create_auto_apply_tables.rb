# Auto-apply (packs/job_applications). Only new tables, so it rolls back cleanly.
class CreateAutoApplyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :auto_apply_employers do |t|
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
    add_index :auto_apply_employers, [ :ats, :identifier ], unique: true

    create_table :auto_apply_postings do |t|
      t.references :employer, null: false, foreign_key: { to_table: :auto_apply_employers, on_delete: :cascade }
      t.string :external_id, null: false
      t.string :title, null: false
      t.string :location
      t.string :country
      t.string :url, null: false
      t.string :apply_url, null: false
      t.text :description
      t.datetime :posted_at
      t.datetime :fetched_at, null: false
      t.datetime :closed_at
      t.timestamps
    end
    add_index :auto_apply_postings, [ :employer_id, :external_id ], unique: true
    add_index :auto_apply_postings, :posted_at
    add_index :auto_apply_postings, :closed_at

    create_table :auto_apply_preferences do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :titles, array: true, null: false, default: []
      t.string :countries, array: true, null: false, default: [ "SA" ]
      t.integer :min_score, null: false, default: 7
      t.integer :daily_cap, null: false, default: 10
      t.string :mode, null: false, default: "review"
      t.string :linkedin_url
      t.datetime :consent_accepted_at
      t.string :consent_version
      t.boolean :paused, null: false, default: false
      t.timestamps
    end

    create_table :auto_apply_applications do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :posting, null: false, foreign_key: { to_table: :auto_apply_postings, on_delete: :cascade }
      # No FK: deleting a resume never blocks on its applications.
      t.bigint :resume_id
      t.string :status, null: false, default: "queued"
      t.integer :score
      t.text :score_reason
      t.text :cover_letter
      t.text :error
      t.jsonb :details, null: false, default: {}
      t.datetime :started_at
      t.datetime :submitted_at
      t.datetime :finished_at
      t.timestamps
    end
    add_index :auto_apply_applications, [ :user_id, :posting_id ], unique: true
    add_index :auto_apply_applications, [ :user_id, :status, :created_at ]

    create_table :auto_apply_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :auto_apply_tokens, :token_digest, unique: true

    create_table :auto_apply_ai_usages do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.integer :scores, null: false, default: 0
      t.integer :answers, null: false, default: 0
      t.timestamps
    end
    add_index :auto_apply_ai_usages, [ :user_id, :day ], unique: true
  end
end
