class CreateResumes < ActiveRecord::Migration[8.0]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.string :target_position
      t.text :summary
      t.integer :ats_score
      t.json :ats_keywords

      t.timestamps
    end
  end
end
