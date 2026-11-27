# Seera Apply: daily job feeds, AI matching and the "Jobs for you" page.
# Talks to resume_builder only through ResumeBuilder::PublicApi.
module JobApplications
  # Off unless SEERA_APPLY_ENABLED is "true". SEERA_APPLY_TESTERS is a
  # comma-separated list of emails that see it while it's off.
  def self.enabled_for?(user)
    return false unless user
    return true if ENV["SEERA_APPLY_ENABLED"] == "true"

    testers = ENV.fetch("SEERA_APPLY_TESTERS", "").split(",").map { |email| email.strip.downcase }
    testers.include?(user.email.to_s.downcase)
  end

  # True when anyone at all can use it, so the daily fetch stays dark until launch.
  def self.enabled_anywhere?
    ENV["SEERA_APPLY_ENABLED"] == "true" || ENV["SEERA_APPLY_TESTERS"].present?
  end

  # JobApplications::Employer lives in apply_employers, and so on.
  def self.table_name_prefix = "apply_"

  DAILY_SCORE_LIMIT = 40 # postings the AI scores per user per day
  MIN_SCORE = 7          # matches below this are kept (never rescored) but not shown
  CITIES = %w[riyadh jeddah dammam remote].freeze

  # The user's Seera Apply data for UserDataExport.
  def self.export_for(user)
    matches = Match.where(user:).includes(posting: :employer).order(:id).map do |match|
      posting = match.posting
      match.attributes.merge(
        "posting" => { "title" => posting.title, "company" => posting.employer.name, "url" => posting.url, "city" => posting.city }
      )
    end
    { "preference" => Preference.find_by(user:)&.attributes, "matches" => matches }
  end
end
