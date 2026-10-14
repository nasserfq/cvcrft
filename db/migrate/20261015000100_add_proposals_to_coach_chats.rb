class AddProposalsToCoachChats < ActiveRecord::Migration[8.0]
  def change
    # Kept apart from draft so Coach::Draft and create_from_draft never see pending rewrites.
    add_column :coach_chats, :proposals, :jsonb, null: false, default: []
  end
end
