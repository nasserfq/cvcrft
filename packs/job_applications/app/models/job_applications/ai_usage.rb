module JobApplications
  # AI work per user per day: scores (DAILY_SCORE_LIMIT) and apply packs (DAILY_PACK_LIMIT).
  class AiUsage < ApplicationRecord
    COUNTERS = %i[scores packs].freeze

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

    # Takes up to n of what is left under limit today, under a row lock so two
    # runs for one user can't both spend the same budget. Returns how many it took.
    def self.reserve!(user, counter, n, limit, day: Date.current)
      raise ArgumentError, "unknown counter #{counter}" unless COUNTERS.include?(counter.to_sym)

      self.for(user, day)
      transaction do
        row = lock.find_by!(user_id: user.id, day:)
        taken = n.clamp(0, [ limit - row.public_send(counter), 0 ].max)
        row.update_columns(counter => row.public_send(counter) + taken, updated_at: Time.current) if taken.positive?
        taken
      end
    end

    def self.remaining(user, counter, limit)
      [ limit - self.for(user).public_send(counter), 0 ].max
    end
  end
end
