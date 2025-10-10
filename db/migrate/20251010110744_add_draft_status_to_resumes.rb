class AddDraftStatusToResumes < ActiveRecord::Migration[8.0]
  def change
    # Add draft status to resumes
    add_column :resumes, :is_draft, :boolean, default: false, null: false
    add_column :resumes, :draft_data, :json, default: {}

    # Add index for better query performance
    add_index :resumes, :is_draft
    add_index :resumes, [ :user_id, :is_draft ]
  end
end
