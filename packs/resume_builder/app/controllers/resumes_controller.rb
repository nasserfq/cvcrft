class ResumesController < ApplicationController
  ATS_TEMPLATE_FALLBACK = "harvard_classic".freeze
  before_action :authenticate_user!
  before_action :set_resume, only: [ :show, :edit, :update, :destroy, :generate_pdf, :optimize_ats, :resume_draft, :experiences, :skills_section, :educations, :certifications_section, :languages_section ]

  # Skip CSRF protection for JSON requests from frontend
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  # Cap PDF generation at 10 per minute per user: rendering a PDF is expensive,
  # so a tight loop (or a load test) must not be able to pin the box.
  rate_limit to: 10, within: 1.minute, only: :generate_pdf, name: "pdf-generate-user",
             by: -> { current_user&.id }, with: -> { pdf_rate_limited }

  def index
    ResumeDraftDeduplicator.call(current_user)

    # Eager load associations to prevent N+1 queries and use counter cache
    @resumes = current_user.resumes.not_drafts.recent
                           .includes(:work_experiences, :skills)
    @drafts = current_user.resumes.drafts.recent
                          .includes(:work_experiences, :skills)
    @cv_generations = current_user.cv_generations.where(status: "completed").recent

    respond_to do |format|
      format.html
      format.json {
        render json: @resumes.map { |resume|
          resume.as_json(
            only: [ :id, :complete_name, :email, :phone_number, :city, :country, :professional_summary, :professional_summary_english, :created_at, :updated_at ],
            methods: [ :pdf_url ]
          ).merge({
            is_cv_builder: true
          })
        }
      }
    end
  end

  # Progressive loading: show returns only header/minimal data for fast initial load
  def show
    start = Time.now
    @work_experiences = @resume.work_experiences.order(start_date: :asc)
    @skills = @resume.skills.group_by(&:category)
    @ai_translations = @resume.ai_translations.recent

    respond_to do |format|
      format.html
      format.json do
        # Return only header data for fast initial load
        render json: @resume.as_json(only: [
          :id, :complete_name, :email, :phone_number, :city, :country,
          :professional_summary, :professional_summary_english, :created_at, :updated_at
        ], methods: [ :pdf_url ])
      end
    end
    Rails.logger.info "CV show action took #{Time.now - start}s"
  end

  # Progressive section endpoints - each loads independently with caching
  def experiences
    start = Time.now
    experiences = @resume.work_experiences.order(start_date: :asc)
    data = Rails.cache.fetch([ "resume", @resume.id, "experiences" ], expires_in: 10.minutes) do
      experiences.as_json
    end
    Rails.logger.info "CV experiences endpoint took #{Time.now - start}s"
    render json: data
  end

  def skills_section
    start = Time.now
    skills = @resume.skills
    data = Rails.cache.fetch([ "resume", @resume.id, "skills" ], expires_in: 10.minutes) do
      skills.as_json
    end
    Rails.logger.info "CV skills endpoint took #{Time.now - start}s"
    render json: data
  end

  def educations
    start = Time.now
    educations = @resume.educations
    data = Rails.cache.fetch([ "resume", @resume.id, "educations" ], expires_in: 10.minutes) do
      educations.as_json
    end
    Rails.logger.info "CV educations endpoint took #{Time.now - start}s"
    render json: data
  end

  def certifications_section
    start = Time.now
    certifications = @resume.certifications
    data = Rails.cache.fetch([ "resume", @resume.id, "certifications" ], expires_in: 10.minutes) do
      certifications.as_json
    end
    Rails.logger.info "CV certifications endpoint took #{Time.now - start}s"
    render json: data
  end

  def languages_section
    start = Time.now
    languages = @resume.languages
    data = Rails.cache.fetch([ "resume", @resume.id, "languages" ], expires_in: 10.minutes) do
      languages.as_json
    end
    Rails.logger.info "CV languages endpoint took #{Time.now - start}s"
    render json: data
  end

  def new
    ResumeDraftDeduplicator.call(current_user)

    existing_starter = current_user.resumes.drafts.order(updated_at: :desc).find(&:empty_starter_draft?)
    if existing_starter
      flash.keep
      redirect_to edit_resume_path(existing_starter, step: existing_starter.current_draft_step)
      return
    end

    # Create and save a draft resume immediately so auto-save works
    @resume = current_user.resumes.build(
      is_draft: true,
      complete_name: current_user.email&.split("@")&.first || "",
      email: current_user.email || ""
    )
    @resume.save(validate: false) # Save without validation to get an ID for auto-save
  end

  def create
    Rails.logger.info "=== RESUME CREATE ==="
    Rails.logger.info "Current user ID: #{current_user&.id}"
    Rails.logger.info "User signed in: #{user_signed_in?}"
    Rails.logger.info "Request format: #{request.format}"

    if current_user.nil?
      Rails.logger.error "No current user found!"
      respond_to do |format|
        format.html { redirect_to new_user_session_path, alert: t("ux_i18n.resumes.sign_in_to_create") }
        format.json { render json: { error: t("ux_i18n.resumes.authentication_required") }, status: :unauthorized }
      end
      return
    end

    @resume = current_user.resumes.build(resume_params)
    Rails.logger.info "Resume user_id before save: #{@resume.user_id}"

    if @resume.save
      Rails.logger.info "Resume saved successfully with ID: #{@resume.id}, user_id: #{@resume.user_id}"

      # Track resume creation
      track_event("resume_created", { resume_id: @resume.id })

      # Generate the PDF download URL
      pdf_url = "/api/export_pdf?resume_id=#{@resume.id}"
      view_url = "/api/export_pdf?resume_id=#{@resume.id}&view_in_browser=true"

      respond_to do |format|
        format.html { redirect_to @resume, notice: t("ux_i18n.resumes.created") }
        format.json {
          render json: @resume.as_json.merge({
            download_url: pdf_url,
            view_url: view_url,
            pdf_available: true
          }), status: :created
        }
      end
    else
      Rails.logger.error "Resume save failed: #{@resume.errors.full_messages}"
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @resume.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    # For editing resumes, we'll render the same form as new.html.erb
    # The React component will handle loading draft data from the resume object
    render :new
  end

  def update
    if @resume.update(resume_params)
      redirect_to @resume, notice: t("ux_i18n.resumes.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    track_event("resume_deleted", { resume_id: @resume.id })
    @resume.destroy
    respond_to do |format|
      format.html { redirect_to resumes_path, notice: t("ux_i18n.resumes.deleted") }
      format.json { head :no_content }
    end
  end

  def generate_pdf
    begin
      if params[:preview] == "true" && @resume.draft_data.present?
        ResumeDraftSync.sync!(@resume)
        @resume.reload
      end

      selected_template = normalize_ats_template(params[:template])
      # Generate ATS-optimized PDF
      pdf_result = ResumePdfService.generate_pdf(@resume, template: selected_template)

      # Preview vs download
      disposition = params[:preview] == "true" ? "inline" : "attachment"
      filename  = "#{@resume.complete_name || @resume.title || 'resume'}_CV.pdf"

      # Prefer sending raw bytes to avoid partial-content issues in some browsers
      if pdf_result.is_a?(Hash) && pdf_result[:path].present? && File.exist?(pdf_result[:path].to_s)
        file_path = pdf_result[:path].to_s
        Rails.logger.info "Reading PDF bytes from: #{file_path} (disposition=#{disposition})"
        bytes = File.binread(file_path)
        send_data bytes,
                  filename: filename,
                  type: "application/pdf",
                  disposition: disposition
      else
        Rails.logger.info "Sending PDF bytes (#{pdf_result&.bytesize || 0} bytes, disposition=#{disposition})"
        send_data pdf_result,
                  filename: filename,
                  type: "application/pdf",
                  disposition: disposition
      end
    rescue ActiveRecord::RecordInvalid => e
      # Draft entries the models reject (e.g. a start date in the future) are a
      # user error: say which field, not a 500.
      message = e.record.errors.full_messages.to_sentence
      respond_to do |format|
        format.json { render json: { error: message, errors: e.record.errors.full_messages }, status: :unprocessable_entity }
        format.any  { render plain: message, status: :unprocessable_entity, content_type: "text/plain" }
      end
    rescue => e
      Rails.logger.error "Failed to generate/send resume PDF: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { render plain: t("ux_i18n.resumes.pdf_load_failed"), status: :internal_server_error }
        format.any  { head :internal_server_error }
      end
    end
  end

  def optimize_ats
    # AI-powered ATS optimization
    result = AtsOptimizationService.new(@resume).optimize
    if result[:success]
      redirect_to @resume, notice: t("ux_i18n.resumes.ats_optimization_completed")
    else
      redirect_to @resume, alert: t("ux_i18n.resumes.ats_optimization_failed", error: result[:error])
    end
  end

  def save_draft
    Rails.logger.info "=== SAVE RESUME DRAFT ==="
    Rails.logger.info "Resume ID: #{params[:id]}"

    begin
      if params[:id] == "new"
        @resume = find_or_create_draft_resume
        unless @resume.persisted?
          Rails.logger.error "❌ Failed to create resume: #{@resume.errors.full_messages}"
          respond_to do |format|
            format.json { render json: {
              success: false,
              error: t("ux_i18n.resumes.create_failed", errors: @resume.errors.full_messages.join(", "))
            }, status: :unprocessable_entity }
          end
          return
        end
        Rails.logger.info "✅ Draft resume ready with ID: #{@resume.id}"
      else
        # For existing resumes, find the resume
        @resume = current_user.resumes.find(params[:id])
        Rails.logger.info "✅ Found existing resume with ID: #{@resume.id}"
      end

      # Save form data as draft
      draft_data = {
        complete_name: params[:complete_name],
        email: params[:email],
        phone_number: params[:phone_number],
        city: params[:city],
        country: params[:country],
        professional_summary: params[:professional_summary].presence || params[:professional_summary_english],
        professional_summary_english: params[:professional_summary_english].presence || params[:professional_summary],
        education: params[:education],
        work_experience: params[:work_experience],
        skills: params[:skills],
        certifications: params[:certifications],
        languages: params[:languages],
        current_step: params[:current_step],
        # The tab's own stamp, echoed in a 409 so a tab can recognise a write
        # of its own that timed out on its side but was stored here.
        saved_at: params[:saved_at].presence || Time.current.iso8601
      }

      # A tab that sends the updated_at it last loaded or saved cannot
      # overwrite a newer save from another tab: it gets 409 and the
      # current updated_at instead. The lock makes check and write atomic.
      saved = @resume.with_lock do
        next false if stale_draft?(@resume)

        @resume.save_draft(draft_data)
        true
      end
      unless saved
        render json: { error: "stale", updated_at: @resume.updated_at.iso8601(6),
                       saved_at: @resume.draft_data.to_h.with_indifferent_access[:saved_at] }, status: :conflict
        return
      end

      respond_to do |format|
        format.html { redirect_to resumes_path, notice: t("ux_i18n.resumes.draft_saved_flash") }
        format.json { render json: {
          success: true,
          message: t("ux_i18n.resumes.draft_saved"),
          resume_id: @resume.id,
          updated_at: @resume.updated_at.iso8601(6),
          draft_data: @resume.draft_data
        } }
      end
    rescue => e
      Rails.logger.error "Error saving resume draft: #{e.message}"
      respond_to do |format|
        format.html { redirect_to resumes_path, alert: t("ux_i18n.resumes.draft_save_failed_flash") }
        format.json { render json: {
          success: false,
          error: t("ux_i18n.resumes.draft_save_failed", error: e.message)
        }, status: :unprocessable_entity }
      end
    end
  end

  def resume_draft
    Rails.logger.info "=== RESUME DRAFT ==="
    Rails.logger.info "Resume ID: #{@resume.id}"

    if @resume.can_be_resumed?
      # Complete the draft
      @resume.complete_draft

      # Get the step number from draft data
      step_number = @resume.draft_data&.dig("current_step") || 1

      respond_to do |format|
        format.html { redirect_to edit_resume_path(@resume, step: step_number), notice: t("ux_i18n.resumes.draft_resumed_flash", step: step_number) }
        format.json { render json: {
          success: true,
          message: t("ux_i18n.resumes.draft_resumed"),
          resume_id: @resume.id,
          step_number: step_number,
          redirect_url: edit_resume_path(@resume, step: step_number)
        } }
      end
    else
      respond_to do |format|
        format.html { redirect_to resumes_path, alert: t("ux_i18n.resumes.draft_not_resumable_flash") }
        format.json { render json: {
          success: false,
          error: t("ux_i18n.resumes.draft_not_resumable")
        }, status: :unprocessable_entity }
      end
    end
  end

  private

  # Response when the per-user PDF rate limit (10/min) is hit.
  def pdf_rate_limited
    message = t("ux_i18n.resumes.pdf_rate_limited")
    respond_to do |format|
      format.json { render json: { error: message }, status: :too_many_requests }
      format.any  { render plain: message, status: :too_many_requests, content_type: "text/plain" }
    end
  end

  def normalize_ats_template(template_key)
    AtsTemplatePdfService.normalize_template_key(template_key.presence || ATS_TEMPLATE_FALLBACK)
  end

  # True when base_updated_at (ISO 8601, microseconds) is older than the
  # resume. Missing or unreadable means no check, as before.
  def stale_draft?(resume)
    base = params[:base_updated_at].presence
    return false unless base

    resume.updated_at.floor(6) > Time.iso8601(base.to_s)
  rescue ArgumentError
    false
  end

  def find_or_create_draft_resume
    existing_starter = current_user.resumes.drafts.order(updated_at: :desc).find(&:empty_starter_draft?)
    resume = existing_starter || current_user.resumes.build(is_draft: true)

    resume.assign_attributes(draft_resume_attributes)
    resume.is_draft = true
    resume.save(validate: false) unless resume.persisted?
    resume.save(validate: false)
    resume
  end

  def draft_resume_attributes
    {
      complete_name: params[:complete_name].presence || current_user.email&.split("@")&.first,
      email: params[:email].presence || current_user.email,
      phone_number: params[:phone_number],
      city: params[:city],
      country: params[:country],
      professional_summary: params[:professional_summary_english],
      professional_summary_english: params[:professional_summary_english]
    }
  end

  def set_resume
    @resume = current_user.resumes.find(params[:id])
    # Always use AI-generated summary for CV building and PDF generation
    if @resume.professional_summary_english.present?
      @resume.professional_summary = @resume.professional_summary_english
    end
  end

  def resume_params
    params.require(:resume).permit(
      :complete_name, :email, :phone_number, :city, :country,
      :professional_summary, :professional_summary_english,
      educations_attributes: [ :degree, :institution, :start_date, :end_date, :gpa, :is_current ],
      work_experiences_attributes: [ :job_title, :company, :start_date, :end_date, :is_current, responsibilities: [] ],
      skills_attributes: [ :category, skill_names: [] ],
      certifications_attributes: [ :name, :organization, :date ],
      languages_attributes: [ :language, :proficiency ]
    )
  end
end
