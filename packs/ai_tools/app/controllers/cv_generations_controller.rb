class CvGenerationsController < ApplicationController
  include CreditsUpsell

  before_action :authenticate_user!
  before_action :ensure_user_has_resume, only: [ :index, :new, :create, :stats ]
  before_action :set_cv_generation, only: [ :show, :status, :destroy, :retry, :cancel, :download_pdf, :view_pdf, :preview, :save_draft, :resume_draft ]
  before_action :require_saved_resume, only: [ :retry, :resume_draft ]

  # Skip CSRF protection for JSON requests from frontend
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  # Global limit for job-based CV generation (base; coupons may increase per user)
  MAX_JOB_BASED_GENERATIONS = UserUsageLimits::BASE_JOB_BASED_GENERATIONS

  def index
    if params[:recent_with_pdf] == "true"
      # Return most recent completed CV with PDF as JSON
      recent_cv = current_user.cv_generations.where(status: "completed")
                             .where("metadata->>'pdf_generated' = 'true'")
                             .order(created_at: :desc)
                             .first

      if recent_cv
        render json: recent_cv
      else
        render json: { error: "No completed CV with PDF found" }, status: 404
      end
    else
      @cv_generations = current_user.cv_generations.recent

      # Filter by resume_id if provided
      if params[:resume_id].present?
        @cv_generations = @cv_generations.where(resume_id: params[:resume_id])
      end

      respond_to do |format|
        format.html
        format.json { render json: @cv_generations }
      end
    end
  end

  def show
    @resume = @cv_generation.resume if @cv_generation.resume_id

    respond_to do |format|
      format.html
      format.json { render json: @cv_generation }
    end
  end

  def new
    @cv_generation = CvGeneration.new
    @resumes = current_user.resumes.limit(10)  # Show user's resumes for selection
    @recent_cv_generations = current_user.cv_generations.where(status: "completed").recent.limit(3)
    @recent_resumes = current_user.resumes.recent.limit(3)
    @default_ats_template = AtsTemplatePdfService.normalize_template_key(params[:template])
  end

  def create
    Rails.logger.info "=== CV GENERATION CREATE ==="
    Rails.logger.info "Current user ID: #{current_user&.id}"
    Rails.logger.info "User signed in: #{user_signed_in?}"

    if current_user.nil?
      Rails.logger.error "No current user found for CV generation!"
      respond_to do |format|
        format.html { redirect_to new_user_session_path, alert: "Please sign in to generate a CV." }
        format.json { render json: { error: "Authentication required" }, status: :unauthorized }
      end
      return
    end

    # Check CV generation limit (150 per user) - overall limit (only count completed)
    max_cv_generations = 150
    current_cv_count = current_user.cv_generations.where(status: "completed").count

    if current_cv_count >= max_cv_generations
      Rails.logger.warn "User #{current_user.id} has reached overall CV generation limit (#{current_cv_count}/#{max_cv_generations})"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.overall_limit_reached", max: max_cv_generations) }
        format.json { render json: { error: t("ux_i18n2.cv_generations.overall_limit_reached", max: max_cv_generations), limit_reached: true }, status: :unprocessable_entity }
      end
      return
    end

    # Check job-based generation limit (only count completed)
    # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
    limits = current_user.usage_limits
    unless Billing::UsageGate.available?(current_user, :job_based_generation)
      Rails.logger.warn "User #{current_user.id} has reached job-based generation limit (#{limits.job_based_generations_used}/#{limits.max_job_based_generations || '∞'})"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.job_credits_used_with_max", max: limits.max_job_based_generations || "∞") }
        format.json { render json: { error: t("ux_i18n2.cv_generations.job_credits_used_with_max", max: limits.max_job_based_generations || "∞"), limit_reached: true, remaining: 0, **credits_upsell }, status: :too_many_requests }
      end
      return
    end

    user_id = current_user.id
    Rails.logger.info "Using user_id: #{user_id} for CV generation"

    # Initialize the CV generation service
    # The AI only rewrites the professional summary of a saved CV, so one is
    # required. Refuse before a credit is consumed.
    if cv_generation_params[:resume_id].blank?
      respond_to do |format|
        format.html { redirect_to new_cv_generation_path, alert: t("cv_generation.choose_resume") }
        format.json { render json: { error: t("cv_generation.choose_resume") }, status: :unprocessable_entity }
      end
      return
    end

    # resume_id comes from the request: only the user's own resumes may be used.
    resume_id = current_user.resumes.find(cv_generation_params[:resume_id]).id

    charge_key = SecureRandom.uuid
    charge = Billing::UsageGate.allow!(current_user, :job_based_generation, key: charge_key)
    if charge == :blocked
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.job_credits_used") }
        format.json { render json: { error: t("ux_i18n2.cv_generations.job_credits_used"), limit_reached: true, remaining: 0, **credits_upsell }, status: :too_many_requests }
      end
      return
    end

    service = CvGenerationService.new(user_id, resume_id)

    # Generate CV
    ats_template = AtsTemplatePdfService.normalize_template_key(cv_generation_params[:ats_template])

    result = service.generate_cv(
      cv_generation_params[:job_description],
      {
        complete_name: cv_generation_params[:complete_name],
        email: cv_generation_params[:email],
        temperature: (cv_generation_params[:temperature].presence || 0.7).to_f.clamp(0.0, 1.0),
        max_tokens: (cv_generation_params[:max_tokens].presence || 15000).to_i.clamp(1000, 15000),
        ats_template: ats_template,
        force_pdf_regeneration: true,  # Always regenerate PDF when user creates a new CV
        source: "job_description",  # Track the source for limit counting
        overage_key: overage_key(charge, charge_key)
      }.compact
    )

    if result[:status] == "queued"
      # Find the created CV generation record
      cv_generation = CvGeneration.find(result[:cv_generation_id]) if result[:cv_generation_id]

      respond_to do |format|
        if cv_generation
          format.html { redirect_to new_cv_generation_path(cv_generation_id: cv_generation.id), notice: "CV generation job has been queued successfully! The results will appear below when ready." }
          format.json { render json: { redirect_url: new_cv_generation_path(cv_generation_id: cv_generation.id), cv_generation_id: cv_generation.id }, status: :created }
        else
          format.html { redirect_to cv_generations_path, notice: "CV generation job has been queued successfully!" }
          format.json { render json: result, status: :created }
        end
      end
    else
      refund_generation(charge, charge_key)
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity, alert: "Failed to queue CV generation job" }
        format.json { render json: { error: "Failed to queue CV generation job" }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @cv_generation.destroy
    respond_to do |format|
      format.html { redirect_to resumes_path, notice: t("ux_i18n2.cv_generations.deleted") }
      format.json { head :no_content }
    end
  end

  def retry
    if @cv_generation.status == "failed"
      charge_key = "retry:#{@cv_generation.id}:#{SecureRandom.uuid}"
      charge = charge_generation(charge_key)
      return redirect_to @cv_generation, alert: t("ux_i18n2.cv_generations.job_credits_used") if charge == :blocked

      # The retried job runs with the generation's metadata as its options.
      metadata = (@cv_generation.metadata || {}).except("overage_key")
      @cv_generation.update!(metadata: metadata.merge({ "overage_key" => overage_key(charge, charge_key) }.compact))
    end

    user_id = @cv_generation.user_id
    service = CvGenerationService.new(user_id, @cv_generation.resume_id)

    result = service.retry_cv_generation(@cv_generation.id)

    if result[:error]
      refund_generation(charge, charge_key)
      redirect_to @cv_generation, alert: result[:error]
    else
      redirect_to @cv_generation, notice: result[:message]
    end
  end

  def cancel
    user_id = @cv_generation.user_id
    service = CvGenerationService.new(user_id, @cv_generation.resume_id)

    result = service.cancel_cv_generation(@cv_generation.id)

    if result[:error]
      redirect_to @cv_generation, alert: result[:error]
    else
      redirect_to @cv_generation, notice: result[:message]
    end
  end

  def status
    service = CvGenerationService.new(current_user.id, @cv_generation.resume_id)

    result = service.get_cv_generation_status(@cv_generation.id)

    respond_to do |format|
      format.html { render :show }
      format.json { render json: result }
    end
  end

  def stats
    user_id = current_user.id
    service = CvGenerationService.new(user_id)

    @stats = service.get_cv_generation_stats

    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end

  def count
    cv_count = current_user.cv_generations.where(status: "completed").count
    max_cv_generations = 150  # Keep consistent with create action

    respond_to do |format|
      format.json { render json: { count: cv_count, limit: max_cv_generations } }
    end
  end

  def download_pdf
    # Check if we need to force regenerate the PDF
    if params[:regenerate] == "true"
      # Regenerating runs the AI again, so it uses the same allowance as a new generation.
      charge_key = "regenerate:#{@cv_generation.id}:#{SecureRandom.uuid}"
      charge = charge_generation(charge_key)
      return redirect_to @cv_generation, alert: t("ux_i18n2.cv_generations.job_credits_used") if charge == :blocked

      # Call the CV generator job synchronously to regenerate the PDF
      begin
        job_description = @cv_generation.job_description
        resume_id = @cv_generation.resume_id
        user_id = current_user.id

        # Get options from existing metadata
        options = @cv_generation.metadata.slice(
          "complete_name", "email", "temperature", "max_tokens", "ats_template"
        ).merge({
          "force_pdf_regeneration" => true,
          "pdf_cache_hours" => 0  # Bypass cache completely
        })

        # Run the job synchronously
        job = CvGeneratorJob.new
        job.perform(job_description, user_id, resume_id, options)

        # Refresh the CV generation object
        @cv_generation.reload
      rescue => e
        refund_generation(charge, charge_key)
        Rails.logger.error "Error regenerating PDF: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return redirect_to @cv_generation, alert: "Failed to regenerate PDF: #{e.message}"
      end
    end

    # Now attempt to send the PDF (original or regenerated)
    if @cv_generation.metadata&.dig("pdf_generated") && @cv_generation.metadata&.dig("pdf_data")
      pdf_data = Base64.decode64(@cv_generation.metadata["pdf_data"])
      filename = @cv_generation.metadata["pdf_filename"] || "generated_cv.pdf"

      send_data pdf_data,
        filename: filename,
        type: "application/pdf",
        disposition: "attachment"
    else
      redirect_to @cv_generation, alert: "PDF not available for this CV generation"
    end
  end

  def preview
    # Use view_pdf for preview functionality
    view_pdf
  end

  def preview_resume
    @resume = current_user.resumes.find(params[:id])

    # Generate PDF for preview if needed
    unless @resume.metadata&.dig("pdf_data")
      begin
        CvGeneratorJob.new.perform_resume_preview(@resume.id, current_user.id)
        @resume.reload
      rescue => e
        Rails.logger.error "Error generating resume preview: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return redirect_to cv_generations_path, alert: "Failed to generate preview: #{e.message}"
      end
    end

    if @resume.metadata&.dig("pdf_data")
      pdf_data = Base64.decode64(@resume.metadata["pdf_data"])

      # Set proper headers for PDF display
      response.headers["Content-Type"] = "application/pdf"
      response.headers["Content-Disposition"] = "inline"
      response.headers["Content-Length"] = pdf_data.bytesize.to_s
      response.headers["Accept-Ranges"] = "bytes"

      send_data pdf_data,
        filename: "#{@resume.complete_name || 'resume'}_preview.pdf",
        type: "application/pdf",
        disposition: "inline",
        stream: true,
        buffer_size: 4096
    else
      redirect_to cv_generations_path, alert: "Preview not available for this resume"
    end
  end

  def view_pdf
    # Check if we need to force regenerate the PDF
    if params[:regenerate] == "true"
      # Regenerating runs the AI again, so it uses the same allowance as a new generation.
      charge_key = "regenerate:#{@cv_generation.id}:#{SecureRandom.uuid}"
      charge = charge_generation(charge_key)
      return redirect_to @cv_generation, alert: t("ux_i18n2.cv_generations.job_credits_used") if charge == :blocked

      # Use the same regeneration logic as in download_pdf
      begin
        job_description = @cv_generation.job_description
        resume_id = @cv_generation.resume_id
        user_id = current_user.id

        # Get options from existing metadata
        options = @cv_generation.metadata.slice(
          "complete_name", "email", "temperature", "max_tokens", "ats_template"
        ).merge({
          "force_pdf_regeneration" => true,
          "pdf_cache_hours" => 0  # Bypass cache completely
        })

        job = CvGeneratorJob.new
        job.perform(job_description, user_id, resume_id, options)

        @cv_generation.reload
      rescue => e
        refund_generation(charge, charge_key)
        Rails.logger.error "Error regenerating PDF for view: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return redirect_to @cv_generation, alert: "Failed to regenerate PDF: #{e.message}"
      end
    end

    if @cv_generation.metadata&.dig("pdf_generated") && @cv_generation.metadata&.dig("pdf_data")
      pdf_data = Base64.decode64(@cv_generation.metadata["pdf_data"])

      # Set proper headers for PDF display
      response.headers["Content-Type"] = "application/pdf"
      response.headers["Content-Disposition"] = "inline"
      response.headers["Content-Length"] = pdf_data.bytesize.to_s
      response.headers["Accept-Ranges"] = "bytes"

      send_data pdf_data,
        filename: "cv_preview_#{@cv_generation.id}.pdf",
        type: "application/pdf",
        disposition: "inline",
        stream: true,
        buffer_size: 4096
    else
      redirect_to @cv_generation, alert: "PDF not available for this CV generation"
    end
  end

  def save_draft
    Rails.logger.info "=== SAVE DRAFT ==="
    Rails.logger.info "CV Generation ID: #{@cv_generation.id}"

    begin
      # Save form data as draft
      draft_data = {
        job_description: params[:job_description],
        resume_id: params[:resume_id],
        complete_name: params[:complete_name],
        email: params[:email],
        temperature: params[:temperature],
        max_tokens: params[:max_tokens],
        saved_at: Time.current.iso8601
      }

      @cv_generation.save_draft(draft_data)

      respond_to do |format|
        format.html { redirect_to cv_generations_path, notice: t("ux_i18n2.cv_generations.draft_saved_flash") }
        format.json { render json: {
          success: true,
          message: t("ux_i18n2.cv_generations.draft_saved"),
          cv_generation_id: @cv_generation.id,
          draft_data: @cv_generation.draft_data
        } }
      end
    rescue => e
      Rails.logger.error "Error saving draft: #{e.message}"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.draft_save_failed_flash") }
        format.json { render json: {
          success: false,
          error: t("ux_i18n2.cv_generations.draft_save_failed", error: e.message)
        }, status: :unprocessable_entity }
      end
    end
  end

  def resume_draft
    Rails.logger.info "=== RESUME DRAFT ==="
    Rails.logger.info "CV Generation ID: #{@cv_generation.id}"

    if @cv_generation.can_be_resumed?
      charge_key = "draft:#{@cv_generation.id}:#{SecureRandom.uuid}"
      charge = charge_generation(charge_key)
    end

    if charge == :blocked
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.job_credits_used") }
        format.json { render json: { success: false, error: t("ux_i18n2.cv_generations.job_credits_used"), limit_reached: true, **credits_upsell }, status: :too_many_requests }
      end
      return
    end

    if @cv_generation.can_be_resumed?
      # Complete the draft and start processing
      @cv_generation.complete_draft

      # Start the CV generation job
      user_id = @cv_generation.user_id
      service = CvGenerationService.new(user_id, @cv_generation.resume_id)

      draft_data = @cv_generation.resume_data
      result = service.generate_cv(
        draft_data["job_description"],
        {
          complete_name: draft_data["complete_name"],
          email: draft_data["email"],
          temperature: (draft_data["temperature"].presence || 0.7).to_f.clamp(0.0, 1.0),
          max_tokens: (draft_data["max_tokens"].presence || 15000).to_i.clamp(1000, 15000),
          source: "job_description",
          overage_key: overage_key(charge, charge_key)
        }.compact
      )
      refund_generation(charge, charge_key) unless result[:status] == "queued"

      respond_to do |format|
        format.html { redirect_to new_cv_generation_path(cv_generation_id: @cv_generation.id), notice: t("ux_i18n2.cv_generations.draft_resumed_flash") }
        format.json { render json: {
          success: true,
          message: t("ux_i18n2.cv_generations.draft_resumed"),
          cv_generation_id: @cv_generation.id,
          redirect_url: new_cv_generation_path(cv_generation_id: @cv_generation.id)
        } }
      end
    else
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: t("ux_i18n2.cv_generations.draft_not_resumable_flash") }
        format.json { render json: {
          success: false,
          error: t("ux_i18n2.cv_generations.draft_not_resumable")
        }, status: :unprocessable_entity }
      end
    end
  end

  private

  # One job-based generation: free allowance first, then credits while
  # billing is on (Billing::UsageGate). Returns :free, :credit or :blocked.
  def charge_generation(key)
    Billing::UsageGate.allow!(current_user, :job_based_generation, key: key)
  end

  # Passed to CvGeneratorJob so a final failure refunds the credit.
  def overage_key(charge, key)
    key if charge == :credit
  end

  # Gives the credit back when the generation it paid for didn't start.
  def refund_generation(charge, key)
    Billing::UsageGate.refund!(current_user, :job_based_generation, key: key) if charge == :credit
  end

  def set_cv_generation
    @cv_generation = current_user.cv_generations.find(params[:id])
  end


  def cv_generation_params
    params.require(:cv_generation).permit(
      :job_description, :resume_id, :complete_name, :email,
      :temperature, :max_tokens, :ats_template
    )
  end

  # Older generations made without a saved CV can't be re-run: the job only
  # rewrites a saved CV's summary. Refuse before a credit is consumed.
  def require_saved_resume
    return if @cv_generation.resume_id

    respond_to do |format|
      format.html { redirect_to new_cv_generation_path, alert: t("cv_generation.choose_resume") }
      format.json { render json: { success: false, error: t("cv_generation.choose_resume") }, status: :unprocessable_entity }
    end
  end

  def ensure_user_has_resume
    return if current_user.resumes.not_drafts.exists?

    Rails.logger.info "User #{current_user.id} has no completed resumes, redirecting to resume creation"

    respond_to do |format|
      format.html { redirect_to new_resume_path, alert: t("resume.need_resume_for_job") }
      format.json { render json: { error: t("ux_i18n2.cv_generations.need_resume_first"), redirect_url: new_resume_path }, status: :unprocessable_entity }
    end
  end
end
