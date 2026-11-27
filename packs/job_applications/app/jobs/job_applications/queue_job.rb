module JobApplications
  # After matching: creates a preparing application for each new good match
  # of a user who has sending on, within the daily pack budget, and starts
  # building each pack. Browser and email channels go first.
  class QueueJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless JobApplications.enabled_for?(user)
      return unless Profile.find_by(user:)&.sending?

      candidates = Match.shown.where(user:, score: APPLY_MIN_SCORE..)
        .where.not(posting_id: Application.where(user:).select(:posting_id))
        .includes(posting: :employer).order(score: :desc, id: :asc).to_a
      return if candidates.empty?

      rows = candidates.map { |match| { posting: match.posting, channel: Channel.for(match.posting) } }
      rows = rows.sort_by.with_index { |row, index| [ row[:channel] == "manual" ? 1 : 0, index ] }

      # PackBuilder bumps AiUsage packs when a pack is built; rows still
      # preparing count too, so a second run can't go past the limit.
      preparing = Application.where(user:, status: "preparing").count
      taken = [ AiUsage.remaining(user, :packs, DAILY_PACK_LIMIT) - preparing, rows.size ].min
      return unless taken.positive?

      now = Time.current
      inserted = Application.insert_all(
        rows.first(taken).map do |row|
          { user_id: user.id, posting_id: row[:posting].id, status: "preparing", channel: row[:channel], created_at: now, updated_at: now }
        end,
        unique_by: %i[user_id posting_id], returning: %i[id]
      )
      inserted.rows.flatten.each { |id| PrepareJob.perform_later(id) }
    end
  end
end
