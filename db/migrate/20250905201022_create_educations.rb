class CreateEducations < ActiveRecord::Migration[8.0]
  def change
    create_table :educations do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :degree
      t.string :institution
      t.date :start_date
      t.date :end_date
      t.string :gpa
      t.boolean :is_current

      t.timestamps
    end
  end
end
