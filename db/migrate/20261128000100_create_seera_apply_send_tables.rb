# Seera Apply sending (packs/job_applications, plans/seera-apply-send.md). New
# tables plus two nullable or constant-default columns on step-1 tables, so old
# code ignores it and it rolls back cleanly.
class CreateSeeraApplySendTables < ActiveRecord::Migration[8.1]
  def change
    create_table :apply_profiles do |t|
      t.references :user, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :nationality
      t.string :visa_status
      t.string :notice_period
      t.integer :expected_salary_sar
      t.string :phone
      t.string :linkedin_url
      t.string :state, null: false, default: "off"
      t.string :consent_version
      t.datetime :consented_at
      t.jsonb :saved_answers, null: false, default: {}
      t.timestamps
    end

    create_table :apply_applications do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :posting, null: false, foreign_key: { to_table: :apply_postings, on_delete: :cascade }
      t.string :status, null: false, default: "preparing"
      t.string :channel, null: false
      t.boolean :approval_required, null: false, default: false
      t.datetime :approved_at
      t.jsonb :questions, null: false, default: []
      t.jsonb :answers, null: false, default: {}
      t.jsonb :missing, null: false, default: []
      t.text :summary
      t.text :cover_letter
      t.string :hold
      t.string :error_code
      t.integer :attempts, null: false, default: 0
      t.datetime :claimed_at
      t.datetime :submit_clicked_at
      t.datetime :sent_at
      t.string :charge
      t.jsonb :confirmation, null: false, default: {}
      t.timestamps
    end
    add_index :apply_applications, [ :user_id, :posting_id ], unique: true
    add_index :apply_applications, [ :user_id, :status ]
    add_index :apply_applications, [ :status, :updated_at ]

    create_table :apply_documents do |t|
      t.references :application, null: false, index: false, foreign_key: { to_table: :apply_applications, on_delete: :cascade }
      t.string :kind, null: false
      t.string :content_type, null: false
      t.string :filename, null: false
      t.integer :byte_size, null: false
      t.binary :data, null: false
      t.timestamps
    end
    add_index :apply_documents, [ :application_id, :kind ], unique: true

    # application_id has no foreign key: a disclosure outlives the posting
    # cleanup that deletes its application.
    create_table :apply_disclosures do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.bigint :application_id
      t.string :employer_name, null: false
      t.string :channel, null: false
      t.string :recipient, null: false
      t.string :data_categories, array: true, null: false, default: []
      t.string :consent_version, null: false
      t.string :outcome
      t.timestamps
    end
    add_index :apply_disclosures, [ :user_id, :created_at ]

    add_column :apply_ai_usages, :packs, :integer, null: false, default: 0
    add_column :apply_postings, :apply_email, :string
  end
end
