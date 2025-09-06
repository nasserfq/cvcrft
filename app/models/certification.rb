class Certification < ApplicationRecord
  belongs_to :resume
  
  validates :name, presence: true
  validates :organization, presence: true
  validates :date, presence: true
end
