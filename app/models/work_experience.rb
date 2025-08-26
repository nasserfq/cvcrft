class WorkExperience < ApplicationRecord
  belongs_to :resume
  belongs_to :ai_translation, optional: true

  validates :company, presence: true, length: { minimum: 2, maximum: 100 }
  validates :position, presence: true, length: { minimum: 3, maximum: 100 }
  validates :start_date, presence: true
  validates :arabic_description, presence: true, length: { minimum: 20, maximum: 2000 }
  validates :english_description, length: { maximum: 2000 }

  # ATS keywords tracking
  validates :ats_keywords, presence: true

  # Validations
  validate :end_date_after_start_date, if: :end_date?
  validate :start_date_not_in_future

  # Scopes
  scope :chronological, -> { order(start_date: :desc) }
  scope :current, -> { where(end_date: nil) }
  scope :past, -> { where.not(end_date: nil) }

  # Methods
  def duration
    end_date ||= Date.current
    ((end_date - start_date).to_i / 365.25).round(1)
  end

  def current?
    end_date.nil?
  end

  def needs_translation?
    english_description.blank?
  end

  private

  def end_date_after_start_date
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def start_date_not_in_future
    if start_date > Date.current
      errors.add(:start_date, "cannot be in the future")
    end
  end
end
