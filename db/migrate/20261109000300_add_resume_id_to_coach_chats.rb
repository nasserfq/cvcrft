# The resume "Send to Seera" made from this chat, so a second click opens it instead of making another.
class AddResumeIdToCoachChats < ActiveRecord::Migration[8.1]
  def change
    add_reference :coach_chats, :resume, foreign_key: { on_delete: :nullify }
  end
end
