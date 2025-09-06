class AddProfessionalSummaryToResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :resumes, :professional_summary, :text
  end
end
