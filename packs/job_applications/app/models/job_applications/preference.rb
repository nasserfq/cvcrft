module JobApplications
  # What a user wants to apply for, and their auto-apply consent.
  class Preference < ApplicationRecord
    MODES = %w[review auto].freeze

    belongs_to :user

    validates :min_score, inclusion: { in: 1..10 }
    validates :daily_cap, inclusion: { in: 1..DAILY_CAP_MAX }
    validates :mode, inclusion: { in: MODES }
    validates :titles, length: { maximum: 10 }
    validate :countries_are_gulf, :titles_are_short, :linkedin_url_is_linkedin

    def consent_accepted? = consent_version == CONSENT_VERSION && consent_accepted_at.present?

    private

    def countries_are_gulf
      errors.add(:countries, :inclusion) if countries.empty? || (countries - COUNTRIES).any?
    end

    def titles_are_short
      errors.add(:titles, :too_long, count: 80) if titles.any? { |t| t.size > 80 }
    end

    def linkedin_url_is_linkedin
      return if linkedin_url.blank?

      uri = URI.parse(linkedin_url)
      ok = uri.is_a?(URI::HTTPS) && (uri.host == "linkedin.com" || uri.host.to_s.end_with?(".linkedin.com"))
      errors.add(:linkedin_url, :invalid) unless ok
    rescue URI::InvalidURIError
      errors.add(:linkedin_url, :invalid)
    end
  end
end
