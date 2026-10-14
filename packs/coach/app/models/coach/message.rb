module Coach
  class Message < ApplicationRecord
    ROLES = %w[user assistant].freeze

    belongs_to :chat, class_name: "Coach::Chat", foreign_key: :coach_chat_id, inverse_of: :messages

    validates :role, inclusion: { in: ROLES }
    validates :content, presence: true, length: { maximum: 20_000 }
  end
end
