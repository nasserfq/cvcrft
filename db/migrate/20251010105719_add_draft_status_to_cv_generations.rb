class AddDraftStatusToCvGenerations < ActiveRecord::Migration[8.0]
  def change
    # Add draft status to CV generations
    add_column :cv_generations, :is_draft, :boolean, default: false, null: false
    add_column :cv_generations, :draft_data, :json, default: {}
    
    # Add index for better query performance
    add_index :cv_generations, :is_draft
    add_index :cv_generations, [:user_id, :is_draft]
  end
end
