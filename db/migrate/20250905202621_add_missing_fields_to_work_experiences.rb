class AddMissingFieldsToWorkExperiences < ActiveRecord::Migration[8.0]
  def change
    add_column :work_experiences, :job_title, :string
    add_column :work_experiences, :responsibilities, :text
    add_column :work_experiences, :is_current, :boolean
  end
end
