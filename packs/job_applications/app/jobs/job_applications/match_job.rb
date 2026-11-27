module JobApplications
  # Scores new postings for one user, or, after each fetch, every enabled user
  # with titles and cities. An open AI breaker ends the run; the next one picks it up.
  class MatchJob < ApplicationJob
    queue_as :default

    def perform(user_id = nil)
      if user_id
        match(User.find_by(id: user_id))
      else
        Preference.where("cardinality(titles) > 0 AND cardinality(cities) > 0").includes(:user)
          .find_each { |preference| match(preference.user) }
      end
    rescue AiCircuit::OpenError => e
      Rails.logger.warn("[seera_apply] matching stopped: #{e.message}")
    end

    private

    def match(user)
      return unless JobApplications.enabled_for?(user)

      Matcher.new(user).call
    rescue AiCircuit::OpenError
      raise
    rescue StandardError => e
      Rails.logger.error("[seera_apply] matching failed for user #{user.id}: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, tags: { pack: "job_applications" })
    end
  end
end
