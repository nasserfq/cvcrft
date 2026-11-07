class CvGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  STATUSES = %w[processing completed failed cancelled draft].freeze

  # Validations
  validates :job_description, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :ai_model, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :tokens_used, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: "completed") }
  scope :processing, -> { where(status: "processing") }
  scope :failed, -> { where(status: "failed") }
  scope :drafts, -> { where(is_draft: true) }
  scope :not_drafts, -> { where(is_draft: false) }

  # Fails generations left processing since before `older_than` (a killed
  # worker or a lost job) and gives back their credit. Returns how many were
  # failed.
  def self.fail_stale!(older_than:)
    processing.where(updated_at: ...older_than).find_each.count do |generation|
      generation.fail_processing!("timed out")
    end
  end

  # Marks the generation failed and refunds its credit, unless it finished or
  # was cancelled meanwhile. Returns whether it changed.
  def fail_processing!(message)
    failed = with_lock do
      next false unless processing?

      update_columns(status: "failed", metadata: (metadata || {}).merge("error" => message), updated_at: Time.current)
    end
    refund_overage if failed
    failed
  end

  # Moves a running generation to cancelled and refunds its credit. The
  # running job sees the status and stops. Returns whether it changed.
  def cancel!
    cancelled = self.class.where(id: id, status: "processing")
                    .update_all(status: "cancelled", updated_at: Time.current) == 1
    reload
    refund_overage if cancelled
    cancelled
  end

  # Gives back the credit paid for this run, if one was (UsageGate). Safe to
  # call twice.
  def refund_overage
    CvGeneratorJob.refund_overage(user_id, metadata)
  end

  # Methods
  def completed?
    status == "completed"
  end

  def processing?
    status == "processing"
  end

  def failed?
    status == "failed"
  end

  def cancelled?
    status == "cancelled"
  end

  def draft?
    is_draft? || status == "draft"
  end

  # A saved draft that hasn't been started yet. Once resumed it is
  # processing and resuming it again would charge and queue a second run.
  def can_be_resumed?
    draft? && !processing?
  end

  def resume_data
    draft_data || {}
  end

  # A running or finished generation is never turned back into a draft:
  # resuming it would charge and run it again.
  def save_draft(form_data)
    with_lock do
      if processing? || completed?
        errors.add(:status, :invalid)
        raise ActiveRecord::RecordInvalid, self
      end

      update!(
        is_draft: true,
        status: "draft",
        draft_data: form_data,
        updated_at: Time.current
      )
    end
  end

  def complete_draft
    update!(
      is_draft: false,
      status: "processing"
    )
  end
end
