module JobApplications
  # The six setup answers and the consent that let Seera apply for a user.
  # Sending runs only while state is "on" and the current consent is given.
  class Profile < ApplicationRecord
    VISA_STATUSES = %w[saudi_citizen gcc_citizen iqama_transferable iqama_not_transferable needs_sponsorship].freeze
    NOTICE_PERIODS = %w[immediate two_weeks one_month two_months three_months].freeze
    STATES = %w[off on paused].freeze
    PHONE_FORMAT = /\A\+?[0-9 ]{8,16}\z/
    MAX_SAVED_ANSWERS = 200

    belongs_to :user

    validates :nationality, presence: true, length: { maximum: 60 }
    validates :visa_status, inclusion: { in: VISA_STATUSES }
    validates :notice_period, inclusion: { in: NOTICE_PERIODS }
    validates :state, inclusion: { in: STATES }
    validates :expected_salary_sar, numericality: { only_integer: true, greater_than: 0, less_than: 10_000_000 }, allow_nil: true
    validates :phone, format: { with: PHONE_FORMAT }
    validate :linkedin_url_is_linkedin

    # The key saved_answers uses for a question label. Unit 2's PackBuilder
    # matches saved answers with this, so both sides normalize the same way.
    def self.answer_key(label) = label.to_s.unicode_normalize(:nfkc).downcase.gsub(/[[:punct:]]/, " ").squish

    def consented? = consent_version == CONSENT_VERSION && consented_at.present?
    def sending? = state == "on" && consented?
    def paused? = state == "paused"
    def saudi? = visa_status == "saudi_citizen"

    # Turns sending on with the current consent text's version.
    def give_consent!
      update!(consent_version: CONSENT_VERSION, consented_at: Time.current, state: "on")
    end

    def pause!
      update!(state: "paused")
    end

    # Withdrawal: sending stops and consent is cleared, so turning it on again
    # asks for consent again.
    def turn_off!
      update!(state: "off", consent_version: nil, consented_at: nil)
    end

    def saved_answer(label) = saved_answers[self.class.answer_key(label)]

    # Remembers answers by normalized label for the next form that asks the
    # same thing. The caller passes only non-sensitive answers.
    def remember_answers!(by_label)
      fresh = by_label.to_h.filter_map do |label, value|
        key = self.class.answer_key(label)
        [ key, value ] if key.present? && value.present?
      end.to_h
      return if fresh.empty?

      with_lock do
        merged = saved_answers.merge(fresh)
        merged = merged.to_a.last(MAX_SAVED_ANSWERS).to_h
        update_columns(saved_answers: merged, updated_at: Time.current)
      end
    end

    private

    def linkedin_url_is_linkedin
      uri = URI.parse(linkedin_url.to_s)
      host = uri.host.to_s.downcase
      return if uri.is_a?(URI::HTTPS) && (host == "linkedin.com" || host.end_with?(".linkedin.com"))

      errors.add(:linkedin_url, :invalid)
    rescue URI::InvalidURIError
      errors.add(:linkedin_url, :invalid)
    end
  end
end
