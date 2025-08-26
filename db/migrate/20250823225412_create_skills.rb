class CreateSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :skills do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :name
      t.string :level
      t.string :category

      t.timestamps
    end
  end
end
