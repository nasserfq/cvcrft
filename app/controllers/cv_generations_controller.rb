class CvGenerationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_user_has_resume, only: [:index, :new, :create, :stats]
  before_action :set_cv_generation, only: [ :show, :destroy, :retry, :cancel, :download_pdf, :view_pdf ]
  
  # Skip CSRF protection for JSON requests from frontend
  skip_before_action :verify_authenticity_token, only: [:create], if: -> { request.format.json? }

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
        format.html { redirect_to new_user_session_path, alert: 'Please sign in to generate a CV.' }
        format.json { render json: { error: 'Authentication required' }, status: :unauthorized }
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
        max_tokens: cv_generation_params[:max_tokens] || 15000
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
    redirect_to cv_generations_path, notice: "CV generation deleted successfully!"
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

  def download_pdf
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

  def view_pdf
    if @cv_generation.metadata&.dig("pdf_generated") && @cv_generation.metadata&.dig("pdf_data")
      pdf_data = Base64.decode64(@cv_generation.metadata["pdf_data"])

      send_data pdf_data,
        type: "application/pdf",
        disposition: "inline"
    else
      redirect_to @cv_generation, alert: "PDF not available for this CV generation"
    end
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
      format.json { render json: { error: 'يجب عليك إنشاء سيرة ذاتية أولاً قبل إنشاء سير ذاتية مخصصة بناءً على وصف الوظيفة.', redirect_url: resumes_path }, status: :unprocessable_entity }
    end
  end
end
