class CreateCertifications < ActiveRecord::Migration[8.0]
  def change
    create_table :certifications do |t|
      t.references :resume, null: false, foreign_key: true
      t.string :name
      t.string :organization
      t.date :date

      t.timestamps
    end
  end
end
