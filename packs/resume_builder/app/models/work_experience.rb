class WorkExperience < ApplicationRecord
  belongs_to :resume
  belongs_to :ai_translation, optional: true

  # Allow skipping validations for PDF generation
  def skip_validations_for_pdf
    resume.try(:skip_validations_for_pdf)
  end

  # New validations for updated structure - with conditional bypass for PDF generation
  validates :company, presence: true, length: { minimum: 2, maximum: 100 }, unless: :skip_validations_for_pdf
  validates :job_title, presence: true, length: { minimum: 2, maximum: 100 }, unless: :skip_validations_for_pdf # Changed from 3 to 2 characters minimum
  validates :start_date, presence: true, unless: :skip_validations_for_pdf

  # Legacy validations (keeping for backward compatibility)
  validates :position, presence: true, length: { minimum: 3, maximum: 100 }, allow_blank: true
  validates :arabic_description, presence: true, length: { minimum: 20, maximum: 2000 }, allow_blank: true
  validates :english_description, length: { maximum: 2000 }, allow_blank: true
  validates :ats_keywords, presence: true, allow_blank: true

  # Validations
  validate :end_date_after_start_date, if: :end_date?
  validate :start_date_not_in_future

  # Scopes
  scope :chronological, -> { order(start_date: :desc) }
  scope :current, -> { where(end_date: nil) }
  scope :past, -> { where.not(end_date: nil) }

  # Methods
  def duration
    return 0 unless start_date.present?
    end_date_value = end_date.present? ? end_date : Date.current.strftime("%Y-%m")
    start_date_value = start_date

    # Simple calculation for text dates in YYYY-MM format
    if start_date_value.match?(/\d{4}-\d{2}/) && end_date_value.match?(/\d{4}-\d{2}/)
      start_year, start_month = start_date_value.split("-").map(&:to_i)
      end_year, end_month = end_date_value.split("-").map(&:to_i)

      months_diff = (end_year - start_year) * 12 + (end_month - start_month)
      (months_diff / 12.0).round(1)
    else
      0
    end
  end

  def current?
    end_date.blank? || is_current
  end

  def needs_translation?
    english_description.blank?
  end

  private

  def end_date_after_start_date
    return unless end_date.present? && start_date.present?

    if start_date.match?(/\d{4}-\d{2}/) && end_date.match?(/\d{4}-\d{2}/)
      if end_date <= start_date
        errors.add(:end_date, "must be after start date")
      end
    end
  end

  def start_date_not_in_future
    return unless start_date.present?

    if start_date.match?(/\d{4}-\d{2}/)
      current_date = Date.current.strftime("%Y-%m")
      if start_date > current_date
        errors.add(:start_date, "cannot be in the future")
      end
    end
  end
end
