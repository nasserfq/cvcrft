module JobApplications
  # A company whose public ATS job board we read. Seeded from config/employers.yml.
  class Employer < ApplicationRecord
    has_many :postings, class_name: "JobApplications::Posting", inverse_of: :employer

    validates :name, :ats, :identifier, presence: true
    validates :identifier, uniqueness: { scope: :ats }
  end
end
