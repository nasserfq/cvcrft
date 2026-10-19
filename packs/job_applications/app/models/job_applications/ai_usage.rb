module JobApplications
  # AI calls per user per day, so scoring and answering stay within a budget.
  class AiUsage < ApplicationRecord
    COUNTERS = %i[scores answers].freeze

    belongs_to :user

    def self.for(user, day = Date.current)
      find_or_create_by!(user:, day:)
    rescue ActiveRecord::RecordNotUnique
      find_by!(user:, day:)
    end

    # Adds n to one counter atomically, creating today's row if needed.
    def self.bump!(user, counter, n = 1, day: Date.current)
      raise ArgumentError, "unknown counter #{counter}" unless COUNTERS.include?(counter.to_sym)

      now = Time.current
      upsert_all([ { user_id: user.id, day:, created_at: now, updated_at: now } ], unique_by: %i[user_id day], on_duplicate: :skip)
      where(user_id: user.id, day:).update_counters(counter => n)
    end

    def self.remaining(user, counter, limit)
      [ limit - self.for(user).public_send(counter), 0 ].max
    end
  end
end
