class CreateCvGenerations < ActiveRecord::Migration[8.0]
  def change
    create_table :cv_generations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, null: true, foreign_key: true
      t.text :job_description
      t.text :generated_content
      t.string :ai_model
      t.string :status
      t.integer :tokens_used
      t.json :metadata

      t.timestamps
    end
  end
end
