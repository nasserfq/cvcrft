module Coach
  class Chat < ApplicationRecord
    PATHS = %w[scratch import].freeze
    # A turn that hasn't ended by then is treated as dead, so a crashed job can't block the chat.
    TURN_TIMEOUT = 2.minutes

    belongs_to :user
    has_many :messages, class_name: "Coach::Message", foreign_key: :coach_chat_id, inverse_of: :chat

    validates :path, inclusion: { in: PATHS }

    # A turn runs from the user's message until TurnJob saves the reply or gives up (Message#end_turn!).
    # There's no status column: the newest message being the user's, not ended and younger than TURN_TIMEOUT, is a running turn.
    def turn_running?
      last = messages.order(:id).last
      last.present? && last.role == "user" && !last.turn_ended? && last.created_at > TURN_TIMEOUT.ago
    end
  end
end
