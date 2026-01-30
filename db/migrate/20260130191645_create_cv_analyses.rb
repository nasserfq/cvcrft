class CreateCvAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_analyses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :original_filename
      t.text :extracted_text
      t.jsonb :analysis_results, default: {}
      t.text :error_message
      t.string :target_job
      t.string :target_industry
      t.string :language, default: "ar"
      t.string :ai_model
      t.integer :tokens_used
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :cv_analyses, :status
    add_index :cv_analyses, :created_at
  end
end
