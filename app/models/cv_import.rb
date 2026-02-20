class CvImport < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  # Status constants
  STATUSES = %w[pending processing completed failed].freeze

  # Language constants
  LANGUAGES = %w[en ar mixed unknown].freeze

  # Set default status
  after_initialize :set_default_status, if: :new_record?

  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :original_filename, presence: true
  validates :detected_language, inclusion: { in: LANGUAGES }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :arabic, -> { where(detected_language: "ar") }
  scope :english, -> { where(detected_language: "en") }

  # Status helpers
  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  # Language helpers
  def arabic?
    detected_language == "ar"
  end

  def english?
    detected_language == "en"
  end

  # Mark as processing
  def mark_processing!
    update!(status: "processing")
  end

  # Mark as completed with parsed data
  def mark_completed!(data)
    update!(status: "completed", parsed_data: data, error_message: nil)
  end

  # Mark as failed with error message
  def mark_failed!(message)
    update!(status: "failed", error_message: message)
  end

  # Mark language detected
  def mark_language!(lang)
    update!(detected_language: lang)
  end

  private

  def set_default_status
    self.status ||= "pending"
  end
end
