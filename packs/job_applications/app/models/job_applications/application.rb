module JobApplications
  # One user's application to one posting, from match to submission.
  class Application < ApplicationRecord
    STATUSES = %w[queued approved in_progress submitted failed needs_user skipped].freeze
    # Where PATCH from the extension may move an application.
    TRANSITIONS = {
      "in_progress" => %w[submitted failed needs_user skipped],
      "needs_user" => %w[submitted skipped failed]
    }.freeze
    # A browser that crashed mid-application gives it back after this long.
    STALE_AFTER = 30.minutes

    belongs_to :user
    belongs_to :posting, class_name: "JobApplications::Posting", inverse_of: :applications

    validates :status, inclusion: { in: STATUSES }

    scope :submitted_today, -> { where(status: "submitted", submitted_at: Time.current.all_day) }

    # The oldest approved application, locked so two tabs never take the same one.
    def self.next_for(user)
      where(user:, status: "approved").order(:created_at, :id).lock("FOR UPDATE SKIP LOCKED").first
    end

    # Puts applications a browser abandoned back in the queue.
    def self.requeue_stale!(user)
      where(user:, status: "in_progress", started_at: ...STALE_AFTER.ago).update_all(status: "approved", started_at: nil, updated_at: Time.current)
    end

    def can_transition_to?(new_status) = TRANSITIONS.fetch(status, []).include?(new_status)
  end
end
