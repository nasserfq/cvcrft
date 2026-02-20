class CreateCvImports < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :original_filename
      t.text :extracted_text
      t.jsonb :parsed_data, default: {}
      t.text :error_message
      t.string :detected_language
      t.references :resume, null: true, foreign_key: true
      t.string :job_id

      t.timestamps
    end

    add_index :cv_imports, :status
    add_index :cv_imports, :job_id
    add_index :cv_imports, :detected_language
  end
end
