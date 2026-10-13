class Education < ApplicationRecord
  belongs_to :resume

  validates :degree, presence: true
  validates :institution, presence: true
  validates :start_date, presence: true
end
