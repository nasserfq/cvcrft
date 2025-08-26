class CreateAiTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_translations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :resume, null: false, foreign_key: true
      t.text :arabic_text
      t.text :english_text
      t.string :translation_quality
      t.string :ai_model
      t.integer :tokens_used
      t.string :status

      t.timestamps
    end
  end
end
