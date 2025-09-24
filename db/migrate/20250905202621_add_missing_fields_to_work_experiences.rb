class AddMissingFieldsToWorkExperiences < ActiveRecord::Migration[8.0]
  def change
    add_column :work_experiences, :job_title, :string unless column_exists?(:work_experiences, :job_title)
    add_column :work_experiences, :responsibilities, :text unless column_exists?(:work_experiences, :responsibilities)
    add_column :work_experiences, :is_current, :boolean unless column_exists?(:work_experiences, :is_current)
  end
end
