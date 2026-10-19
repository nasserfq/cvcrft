module JobApplications
  # Scores new postings for every user who has consented, after each fetch.
  class MatchJob < ApplicationJob
    queue_as :default

    def perform
      Preference.where(consent_version: CONSENT_VERSION, paused: false).where.not(consent_accepted_at: nil)
        .where("cardinality(titles) > 0").includes(:user).find_each do |preference|
        user = preference.user
        next unless JobApplications.enabled_for?(user)
        next unless ResumeBuilder::PublicApi.latest_complete(user)

        Matcher.new(user).call
      rescue StandardError => e
        Rails.logger.error("[auto_apply] matching failed for user #{preference.user_id}: #{e.class}: #{e.message}")
        Sentry.capture_exception(e, tags: { pack: "job_applications" })
      end
    end
  end
end
