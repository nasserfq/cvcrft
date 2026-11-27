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

  # Sending (plans/seera-apply-send.md, docs/state-machines.md "Seera Apply applications").
  APPLY_MIN_SCORE = 8      # matches at or above this get an apply pack
  DAILY_SEND_LIMIT = 5     # applications sent or sending per user per day (Asia/Riyadh)
  DAILY_PACK_LIMIT = 10    # apply packs built per user per day (apply_ai_usages.packs)
  APPROVALS_REQUIRED = 3   # sent applications before the rest go out without approval
  CONSENT_VERSION = "2026-11-28"
  SUBMITTERS = %w[greenhouse ashby].freeze # lever, workable join after a live tester run passes
  TIME_ZONE = "Asia/Riyadh"

  # Fill and screenshot, never click Submit.
  def self.dry_run? = ENV["SEERA_APPLY_DRY_RUN"] == "true"

  # The user's Seera Apply data for UserDataExport.
  def self.export_for(user)
    matches = Match.where(user:).includes(posting: :employer).order(:id).map do |match|
      posting = match.posting
      match.attributes.merge(
        "posting" => { "title" => posting.title, "company" => posting.employer.name, "url" => posting.url, "city" => posting.city }
      )
    end
    applications = Application.where(user:).order(:id).map(&:attributes)
    disclosures = Disclosure.where(user:).order(:id).map(&:attributes)
    { "preference" => Preference.find_by(user:)&.attributes, "matches" => matches,
      "profile" => Profile.find_by(user:)&.attributes, "applications" => applications, "disclosures" => disclosures }
  end
end
