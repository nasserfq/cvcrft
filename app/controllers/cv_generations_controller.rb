class CvGenerationsController < ApplicationController
  # before_action :authenticate_user!  # Temporarily disabled
  before_action :set_cv_generation, only: [ :show, :destroy, :retry, :cancel, :download_pdf, :view_pdf ]

  def index
    if params[:recent_with_pdf] == "true"
      # Return most recent completed CV with PDF as JSON
      recent_cv = CvGeneration.where(status: "completed")
                             .where("metadata->>'pdf_generated' = 'true'")
                             .order(created_at: :desc)
                             .first

      if recent_cv
        render json: recent_cv
      else
        render json: { error: "No completed CV with PDF found" }, status: 404
      end
    else
      # @cv_generations = current_user.cv_generations.recent  # Temporarily disabled
      @cv_generations = CvGeneration.all.limit(20)  # Show all CV generations temporarily
      
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
    @resumes = Resume.all.limit(10)  # Show available resumes for selection
  end

  def create
    # For now, we'll use a default user ID since authentication is disabled
    user_id = User.first&.id || 1  # Use first user or default to 1

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
    # For now, we'll use a default user ID since authentication is disabled
    user_id = User.first&.id || 1
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
    @cv_generation = CvGeneration.find(params[:id])
  end

  def cv_generation_params
    params.require(:cv_generation).permit(
      :job_description, :resume_id, :complete_name, :email,
      :temperature, :max_tokens
    )
  end
end
