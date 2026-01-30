class LinkedinImport < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  # Status constants
  STATUSES = %w[pending processing completed failed].freeze

  # Set default status
  after_initialize :set_default_status, if: :new_record?

  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :original_filename, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }

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

  # Mark as processing
  def mark_processing!
    update!(status: "processing")
  end

  # Mark as completed with parsed data
  def mark_completed!(data)
    update!(status: "completed", parsed_data: data)
  end

  # Mark as failed with error message
  def mark_failed!(message)
    update!(status: "failed", error_message: message)
  end

  private

  def set_default_status
    self.status ||= "pending"
  end
end
