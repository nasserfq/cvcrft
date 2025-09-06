class AddPersonalInfoToResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :resumes, :complete_name, :string
    add_column :resumes, :email, :string
    add_column :resumes, :phone_number, :string
    add_column :resumes, :city, :string
    add_column :resumes, :country, :string
    add_column :resumes, :professional_summary_english, :text
  end
end
