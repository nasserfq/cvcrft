class CvGenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_user_has_resume, only: [ :index, :new, :create, :stats ]
  before_action :set_cv_generation, only: [ :show, :destroy, :retry, :cancel, :download_pdf, :view_pdf, :save_draft, :resume_draft ]

  # Skip CSRF protection for JSON requests from frontend
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  # Global limit for job-based CV generation
  MAX_JOB_BASED_GENERATIONS = 5

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
  end

  def create
    Rails.logger.info "=== CV GENERATION CREATE ==="
    Rails.logger.info "Current user: #{current_user&.email} (ID: #{current_user&.id})"
    Rails.logger.info "User signed in: #{user_signed_in?}"

    if current_user.nil?
      Rails.logger.error "No current user found for CV generation!"
      respond_to do |format|
        format.html { redirect_to new_user_session_path, alert: "Please sign in to generate a CV." }
        format.json { render json: { error: "Authentication required" }, status: :unauthorized }
      end
      return
    end

    # Check CV generation limit (150 per user) - overall limit
    max_cv_generations = 150
    current_cv_count = current_user.cv_generations.count

    if current_cv_count >= max_cv_generations
      Rails.logger.warn "User #{current_user.email} has reached overall CV generation limit (#{current_cv_count}/#{max_cv_generations})"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: "لقد وصلت إلى الحد الأقصى من إنشاء السير الذاتية (#{max_cv_generations}). يرجى المحاولة لاحقاً." }
        format.json { render json: { error: "لقد وصلت إلى الحد الأقصى من إنشاء السير الذاتية (#{max_cv_generations}). يرجى المحاولة لاحقاً.", limit_reached: true }, status: :unprocessable_entity }
      end
      return
    end

    # Check job-based generation limit (5 per user)
    job_based_count = current_user.cv_generations.where("metadata->>'source' = ?", "job_description").count
    if job_based_count >= MAX_JOB_BASED_GENERATIONS
      Rails.logger.warn "User #{current_user.email} has reached job-based generation limit (#{job_based_count}/#{MAX_JOB_BASED_GENERATIONS})"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: "لقد استخدمت جميع رصيد إنشاء السيرة الذاتية من وصف الوظيفة (#{MAX_JOB_BASED_GENERATIONS})." }
        format.json { render json: { error: "لقد استخدمت جميع رصيد إنشاء السيرة الذاتية من وصف الوظيفة (#{MAX_JOB_BASED_GENERATIONS}).", limit_reached: true, remaining: 0 }, status: :too_many_requests }
      end
      return
    end

    user_id = current_user.id
    Rails.logger.info "Using user_id: #{user_id} for CV generation"

    # Initialize the Azure OpenAI service
    service = AzureOpenaiService.new(user_id, cv_generation_params[:resume_id])

    # Generate CV
    result = service.generate_cv(
      cv_generation_params[:job_description],
      {
        complete_name: cv_generation_params[:complete_name],
        email: cv_generation_params[:email],
        temperature: cv_generation_params[:temperature] || 0.7,
        max_tokens: cv_generation_params[:max_tokens] || 15000,
        force_pdf_regeneration: true,  # Always regenerate PDF when user creates a new CV
        source: "job_description"  # Track the source for limit counting
      }
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
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity, alert: "Failed to queue CV generation job" }
        format.json { render json: { error: "Failed to queue CV generation job" }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @cv_generation.destroy
    respond_to do |format|
      format.html { redirect_to resumes_path, notice: "تم حذف السيرة المولدة بنجاح" }
      format.json { head :no_content }
    end
  end

  def retry
    user_id = @cv_generation.user_id
    service = AzureOpenaiService.new(user_id, @cv_generation.resume_id)

    result = service.retry_cv_generation(@cv_generation.id)

    if result[:error]
      redirect_to @cv_generation, alert: result[:error]
    else
      redirect_to @cv_generation, notice: result[:message]
    end
  end

  def cancel
    user_id = @cv_generation.user_id
    service = AzureOpenaiService.new(user_id, @cv_generation.resume_id)

    result = service.cancel_cv_generation(@cv_generation.id)

    if result[:error]
      redirect_to @cv_generation, alert: result[:error]
    else
      redirect_to @cv_generation, notice: result[:message]
    end
  end

  def status
    @cv_generation = CvGeneration.find(params[:id])
    user_id = @cv_generation.user_id
    service = AzureOpenaiService.new(user_id, @cv_generation.resume_id)

    result = service.get_cv_generation_status(@cv_generation.id)

    respond_to do |format|
      format.html { render :show }
      format.json { render json: result }
    end
  end

  def stats
    user_id = current_user.id
    service = AzureOpenaiService.new(user_id)

    @stats = service.get_cv_generation_stats

    respond_to do |format|
      format.html
      format.json { render json: @stats }
    end
  end

  def count
    cv_count = current_user.cv_generations.count
    max_cv_generations = 150  # Keep consistent with create action

    respond_to do |format|
      format.json { render json: { count: cv_count, limit: max_cv_generations } }
    end
  end

  def download_pdf
    # Check if we need to force regenerate the PDF
    if params[:regenerate] == "true"
      # Call the CV generator job synchronously to regenerate the PDF
      begin
        job_description = @cv_generation.job_description
        resume_id = @cv_generation.resume_id
        user_id = current_user.id

        # Get options from existing metadata
        options = @cv_generation.metadata.slice(
          "complete_name", "email", "temperature", "max_tokens"
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
    @resume = Resume.find(params[:id])

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
      # Use the same regeneration logic as in download_pdf
      begin
        job_description = @cv_generation.job_description
        resume_id = @cv_generation.resume_id
        user_id = current_user.id

        # Get options from existing metadata
        options = @cv_generation.metadata.slice(
          "complete_name", "email", "temperature", "max_tokens"
        ).merge({
          "force_pdf_regeneration" => true,
          "pdf_cache_hours" => 0  # Bypass cache completely
        })

        job = CvGeneratorJob.new
        job.perform(job_description, user_id, resume_id, options)

        @cv_generation.reload
      rescue => e
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
    Rails.logger.info "Draft data: #{params[:draft_data]}"

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
        format.html { redirect_to cv_generations_path, notice: "تم حفظ المسودة بنجاح. يمكنك العودة إليها لاحقاً." }
        format.json { render json: {
          success: true,
          message: "تم حفظ المسودة بنجاح",
          cv_generation_id: @cv_generation.id,
          draft_data: @cv_generation.draft_data
        } }
      end
    rescue => e
      Rails.logger.error "Error saving draft: #{e.message}"
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: "حدث خطأ أثناء حفظ المسودة." }
        format.json { render json: {
          success: false,
          error: "حدث خطأ أثناء حفظ المسودة: #{e.message}"
        }, status: :unprocessable_entity }
      end
    end
  end

  def resume_draft
    Rails.logger.info "=== RESUME DRAFT ==="
    Rails.logger.info "CV Generation ID: #{@cv_generation.id}"

    if @cv_generation.can_be_resumed?
      # Complete the draft and start processing
      @cv_generation.complete_draft

      # Start the CV generation job
      user_id = @cv_generation.user_id
      service = AzureOpenaiService.new(user_id, @cv_generation.resume_id)

      draft_data = @cv_generation.resume_data
      service.generate_cv(
        draft_data["job_description"],
        {
          complete_name: draft_data["complete_name"],
          email: draft_data["email"],
          temperature: draft_data["temperature"] || 0.7,
          max_tokens: draft_data["max_tokens"] || 15000
        }
      )

      respond_to do |format|
        format.html { redirect_to new_cv_generation_path(cv_generation_id: @cv_generation.id), notice: "تم استئناف إنشاء السيرة الذاتية بنجاح!" }
        format.json { render json: {
          success: true,
          message: "تم استئناف إنشاء السيرة الذاتية بنجاح",
          cv_generation_id: @cv_generation.id,
          redirect_url: new_cv_generation_path(cv_generation_id: @cv_generation.id)
        } }
      end
    else
      respond_to do |format|
        format.html { redirect_to cv_generations_path, alert: "لا يمكن استئناف هذه المسودة." }
        format.json { render json: {
          success: false,
          error: "لا يمكن استئناف هذه المسودة"
        }, status: :unprocessable_entity }
      end
    end
  end


  # Admin action to regenerate all PDFs (restricted to admins)
  def regenerate_all_pdfs
    # Check if user is admin
    unless current_user&.admin?
      redirect_to cv_generations_path, alert: "Admin access required"
      return
    end

    # Get all completed CV generations with metadata
    cv_generations = CvGeneration.where(status: "completed")
                                .where("metadata->>'pdf_generated' = 'true'")

    # Count of PDFs to process
    total = cv_generations.count
    processed = 0
    success = 0
    failed = 0

    cv_generations.find_each do |cv_gen|
      begin
        processed += 1

        # Skip if no data available
        unless cv_gen.job_description.present? && cv_gen.user_id.present?
          failed += 1
          next
        end

        # Get basic info
        job_description = cv_gen.job_description
        user_id = cv_gen.user_id
        resume_id = cv_gen.resume_id

        # Run the job with force regeneration
        job = CvGeneratorJob.new
        job.perform(
          job_description,
          user_id,
          resume_id,
          { force_pdf_regeneration: true }
        )

        success += 1

        # Log progress every 5 items
        if processed % 5 == 0
          Rails.logger.info "PDF Regeneration: #{processed}/#{total} processed, #{success} successful, #{failed} failed"
        end

      rescue => e
        failed += 1
        Rails.logger.error "Failed to regenerate PDF for CV ##{cv_gen.id}: #{e.message}"
      end
    end

    # Final stats
    message = "PDF regeneration complete: #{success}/#{total} successful, #{failed} failed"
    Rails.logger.info message
    redirect_to cv_generations_path, notice: message
  end

  private

  def set_cv_generation
    @cv_generation = current_user.cv_generations.find(params[:id])
  end


  def cv_generation_params
    params.require(:cv_generation).permit(
      :job_description, :resume_id, :complete_name, :email,
      :temperature, :max_tokens
    )
  end

  def ensure_user_has_resume
    return unless current_user.resumes.empty?

    Rails.logger.info "User #{current_user.email} has no resumes, redirecting to resume creation"

    respond_to do |format|
      format.html { redirect_to resumes_path, alert: 'يجب عليك إنشاء سيرة ذاتية أولاً قبل إنشاء سير ذاتية مخصصة بناءً على وصف الوظيفة. انقر على "إنشاء سيرة ذاتية جديدة" في الصفحة التالية.' }
      format.json { render json: { error: "\u064A\u062C\u0628 \u0639\u0644\u064A\u0643 \u0625\u0646\u0634\u0627\u0621 \u0633\u064A\u0631\u0629 \u0630\u0627\u062A\u064A\u0629 \u0623\u0648\u0644\u0627\u064B \u0642\u0628\u0644 \u0625\u0646\u0634\u0627\u0621 \u0633\u064A\u0631 \u0630\u0627\u062A\u064A\u0629 \u0645\u062E\u0635\u0635\u0629 \u0628\u0646\u0627\u0621\u064B \u0639\u0644\u0649 \u0648\u0635\u0641 \u0627\u0644\u0648\u0638\u064A\u0641\u0629.", redirect_url: resumes_path }, status: :unprocessable_entity }
    end
  end
end
