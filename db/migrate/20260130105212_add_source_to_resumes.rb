class AddSourceToResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :resumes, :source, :string, default: "manual", null: false
    add_index :resumes, :source
  end
end
