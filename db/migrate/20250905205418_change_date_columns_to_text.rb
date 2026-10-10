class ChangeDateColumnsToText < ActiveRecord::Migration[8.0]
  def change
    # Change education date columns to text
    change_column :educations, :start_date, :text
    change_column :educations, :end_date, :text

    # Change work_experiences date columns to text
    change_column :work_experiences, :start_date, :text
    change_column :work_experiences, :end_date, :text

    # Change certifications date column to text
    change_column :certifications, :date, :text
  end
end
