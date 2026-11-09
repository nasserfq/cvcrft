module Coach
  class Message < ApplicationRecord
    ROLES = %w[user assistant].freeze

    belongs_to :chat, class_name: "Coach::Chat", foreign_key: :coach_chat_id, inverse_of: :messages

    # Encrypted at rest (config/initializers/active_record_encryption.rb): queries can only test it for nil.
    encrypts :content

    validates :role, inclusion: { in: ROLES }
    validates :content, presence: true, length: { maximum: 20_000 }

    # A user message is never edited, so a touch marks a turn that ended without a reply (see Chat#turn_running?).
    def end_turn! = touch
    def turn_ended? = updated_at > created_at
  end
end
