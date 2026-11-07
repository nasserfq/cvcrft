class AiTranslation < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  validates :arabic_text, presence: true, length: { minimum: 5, maximum: 5000 }
  validates :english_text, length: { maximum: 5000 }
  validates :translation_quality, inclusion: { in: %w[low medium high] }, allow_nil: true
  STATUSES = %w[pending processing completed failed].freeze
  UNFINISHED_STATUSES = %w[pending processing].freeze

  validates :status, inclusion: { in: STATUSES }

  # Set default status before creation
  before_create :set_default_status

  # Track AI model used and cost
  validates :ai_model, presence: true
  validates :tokens_used, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }

  # Fails translations left pending or processing since before `older_than`
  # (a killed worker or a lost job) and gives back their credit. Returns how
  # many were failed.
  def self.fail_stale!(older_than:)
    where(status: UNFINISHED_STATUSES).where(updated_at: ...older_than).find_each.count do |translation|
      translation.fail_unfinished!("timed out", error_code: "timeout")
    end
  end

  # Marks the translation failed and refunds its credit, unless it finished
  # meanwhile. Returns whether it changed.
  def fail_unfinished!(message, error_code:)
    failed = with_lock do
      next false unless status.in?(UNFINISHED_STATUSES)

      update_columns(
        status: "failed",
        english_text: "Translation failed: #{message}".truncate(5000),
        metadata: (metadata || {}).merge("error" => message, "error_code" => error_code),
        updated_at: Time.current
      )
    end
    AiTranslationJob.refund_overage(user_id, metadata || {}) if failed
    failed
  end

  # Methods
  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def pending?
    status == "pending"
  end

  def has_quality_score?
    translation_quality.present?
  end

  def estimated_cost
    return 0 unless tokens_used

    # Placeholder for cost calculation based on AI model
    case ai_model
    when "gpt-4" then tokens_used * 0.00003
    when "gpt-3.5-turbo" then tokens_used * 0.000002
    else tokens_used * 0.00001
    end
  end

  private

  def set_default_status
    self.status ||= "pending"
  end
end
