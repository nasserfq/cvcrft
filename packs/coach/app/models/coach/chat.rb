module Coach
  class Chat < ApplicationRecord
    PATHS = %w[scratch import].freeze

    belongs_to :user
    has_many :messages, class_name: "Coach::Message", foreign_key: :coach_chat_id, inverse_of: :chat

    validates :path, inclusion: { in: PATHS }
  end
end
