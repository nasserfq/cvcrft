require "prawn"
require "prawn/table"
require "json"
require "base64"
require "ostruct" # For potentially complex data parsing
require "active_support/core_ext/hash/keys" # Needed for deep_symbolize_keys

class CvGeneratorJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  # Errors a retry can't fix go straight to retries_exhausted.
  NON_RETRYABLE_ERRORS = [ ArgumentError, ActiveRecord::RecordNotFound ].freeze
  # An open AI breaker (AiCircuit) waits for it to close.
  sidekiq_retry_in do |_count, error|
    next :kill if NON_RETRYABLE_ERRORS.any? { |klass| error.is_a?(klass) }

    AiCircuit.retry_delay(error)
  end

  # A generation that ran past the free allowance was paid with a credit
  # (Billing::UsageGate); options["overage_key"], a random id, is set only
  # then. A final failure marks the generation failed and gives the credit
  # back. Safe to call twice.
  sidekiq_retries_exhausted do |job, error|
    job_description, user_id, _resume_id, options = job["args"]
    generation = find_generation(user_id, job_description, options)
    generation&.fail_processing!(error&.message || "failed")
    refund_overage(user_id, options)
  end

  def self.refund_overage(user_id, options)
    key = (options || {}).transform_keys(&:to_s)["overage_key"].presence
    user = key && User.find_by(id: user_id)
    Billing::UsageGate.refund!(user, :job_based_generation, key: key) if user
  end

  # options["cv_generation_id"] names the row this run is for. Jobs enqueued
  # before it was passed fall back to the user's processing row with the same
  # job description.
  def self.find_generation(user_id, job_description, options)
    id = (options || {}).transform_keys(&:to_s)["cv_generation_id"]
    generations = CvGeneration.where(user_id: user_id)
    return generations.find_by(id: id) if id.present?

    generations.where(job_description: job_description, status: "processing").order(created_at: :desc).first
  end

  # The options a run reads; anything else in a generation's metadata
  # (generated data, the PDF, errors) is never passed back to the job.
  OPTION_KEYS = %w[complete_name email temperature max_tokens ats_template source overage_key].freeze

  # options["regenerate"] re-runs a completed generation in place (the
  # controller's regenerate PDF). Any other run needs a processing row and
  # stops when the row is cancelled meanwhile. The new summary and its PDF
  # are written together only when both worked, so a failed run leaves the
  # generation as it was.
  def perform(job_description, user_id, resume_id = nil, options = {})
    Rails.logger.info "=== CV GENERATOR JOB STARTED ==="
    Rails.logger.info "Job Description: #{job_description.truncate(200)}"

    @job_description = job_description
    @user_id = user_id
    @resume_id = resume_id
    @options = (options || {}).transform_keys(&:to_sym)

    @cv_generation = find_cv_generation_record
    if @options[:cv_generation_id].present?
      return Rails.logger.info("CvGeneration #{@options[:cv_generation_id]} not found; nothing to do") if @cv_generation.nil?
      return Rails.logger.info("CvGeneration #{@cv_generation.id} is #{@cv_generation.status}; skipping") unless runnable?
    end

    # The AI only rewrites the professional summary of a saved CV; it never
    # builds a new one. Fail before anything is created.
    raise ArgumentError, "resume_id is required" if @resume_id.blank?

    # Jobs enqueued without an id and with no processing row get a new one
    if @cv_generation.nil?
      Rails.logger.info "Creating CvGeneration record for processing state"
      @cv_generation = CvGeneration.create!(
        user_id: @user_id,
        resume_id: @resume_id,
        job_description: @job_description,
        generated_content: nil,
        ai_model: AiModel.default,
        status: "processing",
        tokens_used: nil,
        metadata: @options.deep_stringify_keys
      )
    end

    # The saved resume is only the source: it is never updated here.
    resume = owned_resume
    @snapshot = CvGenerator::ResumeSnapshot.new(resume).to_h

    result = call_azure_openai_api
    return log_cancelled if CvGeneration.where(id: @cv_generation.id, status: "cancelled").exists?

    generated_data = CvGenerator::ResultPersister.generated_data(result, snapshot: @snapshot)
    pdf_metadata = CvGenerator::PdfRenderer.new(resume, selected_ats_template_key).call(generated_data)

    return log_cancelled unless CvGenerator::ResultPersister.new(@cv_generation).record!(result, snapshot: @snapshot, pdf_metadata: pdf_metadata)
    return log_cancelled unless mark_completed

    Rails.logger.info "=== CV GENERATION COMPLETED SUCCESSFULLY ==="
  rescue => e
    Rails.logger.error "=== CV GENERATION FAILED ==="
    Rails.logger.error "Error: #{e.message}"
    handle_cv_generation_error(e)
    raise e
  end

  private

  # The resume must belong to the user this job runs for; resume_id comes
  # from the request, so never load it unscoped.
  def owned_resume
    Resume.find_by!(id: @resume_id, user_id: @user_id)
  end

  def find_cv_generation_record
    self.class.find_generation(@user_id, @job_description, @options)
  end

  def runnable?
    @cv_generation.processing? || (@cv_generation.completed? && @options[:regenerate].present?)
  end

  # Completes a processing row unless it was cancelled meanwhile; a
  # regenerated row is already completed.
  def mark_completed
    return true if @cv_generation.completed?

    CvGeneration.where(id: @cv_generation.id, status: "processing")
                .update_all(status: "completed", updated_at: Time.current) == 1
  end

  def log_cancelled
    Rails.logger.info "CvGeneration #{@cv_generation.id} was cancelled; stopping"
  end

  def call_azure_openai_api
    prompts = CvGenerator::PromptBuilder.new(job_description: @job_description, snapshot: @snapshot)
    response = AiModel.complete(system: prompts.system_prompt, user: prompts.user_prompt,
                                temperature: (@options[:temperature] || 0.7).to_f, max_tokens: (@options[:max_tokens] || 10000).to_i,
                                check: "Is the professional summary in the output strong, in English, tailored to the job in the input, and free of facts the input does not support?")
    result = CvGenerator::ResponseParser.new(snapshot: @snapshot).call(response)
    result[:professional_summary] = CvGenerator::EnglishSummary.new.call(result[:professional_summary])
    result
  end

  def selected_ats_template_key
    @options[:ats_template] || @cv_generation.metadata&.dig("ats_template")
  end

  # A processing row stays processing between attempts, with the error
  # noted; it is failed (and refunded) when retries are exhausted, or now for
  # an error a retry can't fix. Other rows (a regenerated completed one, a
  # cancelled one) keep their status.
  def handle_cv_generation_error(e)
    @cv_generation ||= find_cv_generation_record
    unless @cv_generation
      Rails.logger.error "No CvGeneration record available to update error metadata"
      return
    end

    @cv_generation = CvGeneration.find_by(id: @cv_generation.id)
    return unless @cv_generation&.processing?

    if NON_RETRYABLE_ERRORS.any? { |klass| e.is_a?(klass) }
      @cv_generation.fail_processing!(e.message)
    else
      @cv_generation.update_columns(
        metadata: (@cv_generation.metadata || {}).merge("error" => e.message, "error_backtrace" => e.backtrace),
        updated_at: Time.current
      )
    end
  end
end
