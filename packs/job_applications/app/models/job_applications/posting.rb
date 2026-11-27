module JobApplications
  # One job from an employer's feed. Closed when a fetch no longer sees it.
  class Posting < ApplicationRecord
    belongs_to :employer, class_name: "JobApplications::Employer", inverse_of: :postings
    has_many :matches, class_name: "JobApplications::Match", inverse_of: :posting, dependent: :delete_all

    validates :external_id, :title, :url, :apply_url, :fetched_at, presence: true
    validate :urls_are_web_links

    scope :open, -> { where(closed_at: nil) }
    scope :fresh, -> { where(fetched_at: 2.days.ago..) }

    private

    def urls_are_web_links
      %i[url apply_url].each do |attribute|
        value = public_send(attribute)
        errors.add(attribute, :invalid) if value.present? && !WebUrl.valid?(value)
      end
    end
  end
end
