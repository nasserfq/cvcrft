class Certification < ApplicationRecord
  belongs_to :resume

  validates :name, presence: true
  validates :organization, presence: true
  # Date is optional since LinkedIn certifications may not have dates
end
