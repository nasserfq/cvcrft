class CvGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  STATUSES = %w[processing completed failed cancelled draft].freeze

  # The metadata keys the pages read from a generation's JSON (the pollers and
  # list on cv_generations/new). The rest stays on the server: the base64 PDF
  # (served by download_pdf and view_pdf), the raw AI reply, the generated
  # data, the job options and the error with its backtrace.
  CLIENT_METADATA_KEYS = %w[pdf_generated pdf_size pdf_filename pdf_path pdf_error complete_name email].freeze

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
  # Rows the CV builder's PDF export used to write (ai_model "cv_builder";
  # no longer created) hold no AI output or PDF; lists, limits and
  # regenerators leave them out.
  scope :ai_generated, -> { where("cv_generations.ai_model IS DISTINCT FROM ?", "cv_builder") }

  # The longest a generation can stay processing: StaleWorkSweeperJob fails
  # it STALE_AFTER after its last update and runs every 10 minutes
  # (config/schedule.yml). Pages waiting on a generation poll this long.
  MAX_PROCESSING_TIME = StaleWorkSweeperJob::STALE_AFTER + 10.minutes

  # How long a regenerate holds its claim on a completed generation; an
  # older claim is from a request that died and may be taken over.
  REGENERATE_CLAIM_TTL = 10.minutes

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

  # Every JSON render of a generation (show, index, status) carries only
  # client_metadata, so a new endpoint can't leak the PDF or a backtrace.
  def as_json(options = nil)
    json = super
    json["metadata"] = client_metadata if json.key?("metadata")
    json
  end

  def client_metadata
    (metadata || {}).slice(*CLIENT_METADATA_KEYS)
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

  # Claims this completed generation for one regenerate run, so a double
  # click or a second tab doesn't run (and charge) it twice. Returns whether
  # the claim was taken; release it with release_regeneration!.
  def claim_regeneration!
    with_lock do
      claimed_at = metadata&.dig("regenerating_at").to_i
      next false unless completed? && claimed_at < REGENERATE_CLAIM_TTL.ago.to_i

      update_columns(metadata: (metadata || {}).merge("regenerating_at" => Time.current.to_i))
      true
    end
  end

  # Drops the claim after a failed regenerate; a successful one drops it in
  # the same write as the new content (CvGenerator::ResultPersister).
  def release_regeneration!
    with_lock do
      update_columns(metadata: metadata.except("regenerating_at")) if metadata&.key?("regenerating_at")
    end
  end
end
