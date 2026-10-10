class Language < ApplicationRecord
  belongs_to :resume

  validates :language, presence: true
  validates :proficiency, presence: true
end
