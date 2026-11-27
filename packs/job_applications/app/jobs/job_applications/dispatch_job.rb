module JobApplications
  # Every 15 minutes (config/schedule.yml): one SendJob per user for their
  # oldest queued application, approved ones first. Picks up rows a hold kept
  # back, and paces automatic sends.
  class DispatchJob < ApplicationJob
    queue_as :default

    def perform
      return unless JobApplications.enabled_anywhere?

      users_with_sending = Application.where(status: "sending").select(:user_id)
      Application.where(status: "queued").where.not(user_id: users_with_sending)
        .select("DISTINCT ON (user_id) id, user_id")
        .order(Arel.sql("user_id, approved_at IS NULL, approved_at, created_at, id"))
        .includes(:user).each do |application|
        SendJob.perform_later(application.id) if JobApplications.enabled_for?(application.user)
      end
    end
  end
end
