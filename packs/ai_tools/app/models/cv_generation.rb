class CvGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  # Validations
  validates :job_description, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :ai_model, presence: true
  validates :status, presence: true, inclusion: { in: %w[processing completed failed cancelled draft] }
  validates :tokens_used, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: "completed") }
  scope :processing, -> { where(status: "processing") }
  scope :failed, -> { where(status: "failed") }
  scope :drafts, -> { where(is_draft: true) }
  scope :not_drafts, -> { where(is_draft: false) }

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

  def save_draft(form_data)
    update!(
      is_draft: true,
      status: "draft",
      draft_data: form_data,
      updated_at: Time.current
    )
  end

  def complete_draft
    update!(
      is_draft: false,
      status: "processing"
    )
  end
end
