module JobApplications
  # The job titles and cities a user wants matches for.
  class Preference < ApplicationRecord
    MAX_TITLES = 10
    MAX_TITLE_LENGTH = 80

    belongs_to :user

    validates :titles, length: { maximum: MAX_TITLES }
    validate :titles_are_short, :cities_are_known

    def ready? = titles.any? && cities.any?

    private

    def titles_are_short
      errors.add(:titles, :too_long, count: MAX_TITLE_LENGTH) if titles.any? { |t| t.to_s.size > MAX_TITLE_LENGTH }
    end

    def cities_are_known
      errors.add(:cities, :inclusion) if (cities - CITIES).any?
    end
  end
end
