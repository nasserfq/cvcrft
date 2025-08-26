class CreateWorkExperiences < ActiveRecord::Migration[8.0]
  def change
    create_table :work_experiences do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :company
      t.string :position
      t.date :start_date
      t.date :end_date
      t.text :arabic_description
      t.text :english_description
      t.json :ats_keywords

      t.timestamps
    end
  end
end
