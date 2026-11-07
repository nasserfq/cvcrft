class CvAnalysis < ApplicationRecord
  belongs_to :user

  # Status constants
  STATUSES = %w[pending processing completed failed].freeze
  UNFINISHED_STATUSES = %w[pending processing].freeze
  LANGUAGES = %w[ar en].freeze

  # Set default status
  after_initialize :set_defaults, if: :new_record?

  # Fails analyses left pending or processing since before `older_than` (a
  # lost job or a killed worker). Nothing was charged, so nothing is given
  # back. Returns how many were failed.
  def self.fail_stale!(older_than:)
    where(status: UNFINISHED_STATUSES).where(updated_at: ...older_than).find_each.count do |analysis|
      analysis.fail_unfinished!("timed out")
    end
  end

  # Validations
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :language, inclusion: { in: LANGUAGES }, allow_blank: true
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

  # State transitions
  # Progress starts at 3 so the processing page shows movement before the
  # first streamed chunk arrives; the job raises it to at most 95. A retried
  # attempt starts over, so the last attempt's error is cleared.
  def mark_processing!
    update!(status: "processing", progress: 3, error_message: nil)
  end

  def mark_completed!(results, model_name = nil, tokens = nil)
    update!(
      status: "completed",
      progress: 100,
      analysis_results: results,
      ai_model: model_name,
      tokens_used: tokens
    )
  end

  def mark_failed!(message)
    update!(
      status: "failed",
      error_message: message
    )
  end

  # Marks the analysis failed unless it finished meanwhile. Returns whether
  # it changed.
  def fail_unfinished!(message)
    with_lock do
      next false unless status.in?(UNFINISHED_STATUSES)

      mark_failed!(message)
    end
  end

  # Analysis results helpers
  def overall_score
    analysis_results&.dig("overall_score") || 0
  end

  def section_scores
    analysis_results&.dig("section_scores") || {}
  end

  def strengths
    analysis_results&.dig("strengths") || []
  end

  def improvements
    analysis_results&.dig("improvements") || []
  end

  def ats_tips
    analysis_results&.dig("ats_tips") || []
  end

  def detailed_feedback
    analysis_results&.dig("detailed_feedback") || {}
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.language ||= "ar"
    self.analysis_results ||= {}
    self.metadata ||= {}
  end
end
