# Auto-apply: job feeds, matching, the apply queue and the extension API.
# Talks to resume_builder only through ResumeBuilder::PublicApi.
module JobApplications
  # Off unless AUTO_APPLY_ENABLED is "true". AUTO_APPLY_TESTERS is a
  # comma-separated list of emails that see it while it's off.
  def self.enabled_for?(user)
    return false unless user
    return true if ENV["AUTO_APPLY_ENABLED"] == "true"

    testers = ENV.fetch("AUTO_APPLY_TESTERS", "").split(",").map { |email| email.strip.downcase }
    testers.include?(user.email.to_s.downcase)
  end

  # True when anyone at all can use it, so the daily fetch stays dark until launch.
  def self.enabled_anywhere?
    ENV["AUTO_APPLY_ENABLED"] == "true" || ENV["AUTO_APPLY_TESTERS"].present?
  end

  # JobApplications::Employer lives in auto_apply_employers, and so on.
  def self.table_name_prefix = "auto_apply_"

  # Bump when the consent text (auto_apply.consent.body) changes.
  CONSENT_VERSION = "2026-10-20"
  COUNTRIES = %w[SA AE QA KW BH OM].freeze
  DAILY_CAP_MAX = 25
  DAILY_SCORE_LIMIT = 40      # AI scoring calls per user per day
  DAILY_ANSWER_LIMIT = 60     # answers + cover-letter calls per user per day

  # Applications submitted today, and how many more the user's cap allows.
  def self.today(user, preference = Preference.find_by(user:))
    submitted = Application.where(user:).submitted_today.count
    cap = preference&.daily_cap || Preference.new.daily_cap
    { "submitted" => submitted, "remaining" => [ cap - submitted, 0 ].max,
      "in_progress" => Application.where(user:, status: "in_progress").count }
  end
end
