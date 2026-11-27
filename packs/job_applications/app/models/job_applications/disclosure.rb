module JobApplications
  # PDPL log: one row per send attempt, written before the submit, saying
  # which employer got which kinds of the user's data and under which consent.
  # Kept for the life of the account (no foreign key to the application, which
  # the posting cleanup deletes) and included in the data export.
  class Disclosure < ApplicationRecord
    DATA_CATEGORIES = %w[name email phone city linkedin_url cv nationality visa_status notice_period
                         expected_salary form_answers].freeze
    OUTCOMES = %w[sent fallback retry error].freeze

    belongs_to :user

    validates :employer_name, :channel, :recipient, :consent_version, presence: true
    validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true

    def self.record!(application)
      posting = application.posting
      profile = Profile.find_by!(user_id: application.user_id)
      categories = DATA_CATEGORIES - (profile.expected_salary_sar ? [] : %w[expected_salary])
      create!(user_id: application.user_id, application_id: application.id, employer_name: posting.employer.name,
              channel: application.channel, recipient: recipient_for(application), data_categories: categories,
              consent_version: profile.consent_version || CONSENT_VERSION)
    end

    # The employer's host for a browser send, the address for an email.
    def self.recipient_for(application)
      posting = application.posting
      return posting.apply_email.to_s if application.channel == "email"

      URI.parse(posting.apply_url.to_s).host.to_s.presence || posting.apply_url
    rescue URI::InvalidURIError
      posting.apply_url
    end

    def mark!(outcome)
      update_columns(outcome:, updated_at: Time.current)
    end
  end
end
