class CreateLinkedinImports < ActiveRecord::Migration[8.0]
  def change
    create_table :linkedin_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :original_filename
      t.text :extracted_text
      t.jsonb :parsed_data, default: {}
      t.text :error_message
      t.references :resume, null: true, foreign_key: true
      t.string :job_id

      t.timestamps
    end

    add_index :linkedin_imports, :status
    add_index :linkedin_imports, :job_id
  end
end
