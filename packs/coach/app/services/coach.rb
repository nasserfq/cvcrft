# AI Coach. Talks to resume_builder only through ResumeBuilder::PublicApi.
module Coach
  # Off unless COACH_ENABLED is "true". COACH_TESTERS is a comma-separated
  # list of emails that see it while it's off, for trying it in production.
  def self.enabled_for?(user)
    return false unless user
    return true if ENV["COACH_ENABLED"] == "true"

    testers = ENV.fetch("COACH_TESTERS", "").split(",").map { |email| email.strip.downcase }
    testers.include?(user.email.to_s.downcase)
  end
end
