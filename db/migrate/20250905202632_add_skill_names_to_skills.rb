class AddSkillNamesToSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :skills, :skill_names, :text unless column_exists?(:skills, :skill_names)
  end
end
