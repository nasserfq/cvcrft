class LinkedinImport < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  # Encrypted at rest (config/initializers/active_record_encryption.rb): queries can only test it for nil.
  encrypts :extracted_text

  # Status constants
  STATUSES = %w[pending processing completed failed].freeze
  # A failed import is final: it is written only once Sidekiq's retries are
  # used up (or by fail_stale!), after the credit was given back.
  TERMINAL_STATUSES = %w[completed failed].freeze
  ACTIVE_STATUSES = %w[pending processing].freeze

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

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  # The key the import's charge is recorded under (Billing::UsageGate), so a
  # failure can give the credit back from the row alone.
  def charge_key
    "linkedin_import:#{id}"
  end

  def refund_charge!
    Billing::UsageGate.refund!(user, :document_ai, key: charge_key)
  end

  # Moves a pending/processing import to failed and gives its credit back.
  # The conditional update never overwrites an import that finished
  # meanwhile. Returns whether this call changed the row.
  def self.fail_active!(id, message)
    changed = where(id: id, status: ACTIVE_STATUSES)
                .update_all(status: "failed", error_message: message, updated_at: Time.current) == 1
    find_by(id: id)&.refund_charge! if changed
    changed
  end

  # Fails imports stuck in pending/processing since before older_than (a
  # job that died without Sidekiq noticing). Returns how many were changed.
  def self.fail_stale!(older_than:)
    where(status: ACTIVE_STATUSES).where(updated_at: ...older_than).pluck(:id)
      .count { |id| fail_active!(id, "timed out") }
  end

  private

  def set_default_status
    self.status ||= "pending"
  end
end
