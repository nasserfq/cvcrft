class ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [ :show, :edit, :update, :destroy, :generate_pdf, :optimize_ats ]

  # Skip CSRF protection for JSON requests from frontend
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  def index
    @resumes = current_user.resumes.recent
    @cv_generations = current_user.cv_generations.where(status: "completed").recent

    respond_to do |format|
      format.html
      format.json {
        render json: @resumes.as_json(
          only: [ :id, :complete_name, :email, :phone_number, :city, :country, :professional_summary, :professional_summary_english, :created_at, :updated_at ]
        )
      }
    end
  end

  def test_auth
    Rails.logger.info "=== TEST AUTH ENDPOINT ==="
    Rails.logger.info "Current user: #{current_user&.email} (ID: #{current_user&.id})"
    Rails.logger.info "User signed in: #{user_signed_in?}"
    Rails.logger.info "Request format: #{request.format}"
    Rails.logger.info "Headers: #{request.headers.to_h.select { |k, v| k.include?('auth') || k.include?('csrf') || k.include?('content') }}"

    render json: {
      current_user: current_user&.email,
      user_id: current_user&.id,
      signed_in: user_signed_in?,
      format: request.format.to_s
    }
  end

  def show
    @work_experiences = @resume.work_experiences.chronological
    @skills = @resume.skills.group_by(&:category)
    @ai_translations = @resume.ai_translations.recent

    respond_to do |format|
      format.html
      format.json {
        render json: @resume.as_json(
          include: {
            work_experiences: {},
            skills: {},
            educations: {},
            certifications: {},
            languages: {}
          }
        )
      }
    end
  end

  def new
    @resume = current_user.resumes.build
  end

  def create
    Rails.logger.info "=== RESUME CREATE ==="
    Rails.logger.info "Current user: #{current_user&.email} (ID: #{current_user&.id})"
    Rails.logger.info "User signed in: #{user_signed_in?}"
    Rails.logger.info "Request format: #{request.format}"
    Rails.logger.info "Resume params: #{resume_params.inspect}"

    if current_user.nil?
      Rails.logger.error "No current user found!"
      respond_to do |format|
        format.html { redirect_to new_user_session_path, alert: "Please sign in to create a resume." }
        format.json { render json: { error: "Authentication required" }, status: :unauthorized }
      end
      return
    end

    @resume = current_user.resumes.build(resume_params)
    Rails.logger.info "Resume user_id before save: #{@resume.user_id}"

    if @resume.save
      Rails.logger.info "Resume saved successfully with ID: #{@resume.id}, user_id: #{@resume.user_id}"
      respond_to do |format|
        format.html { redirect_to @resume, notice: "Resume created successfully!" }
        format.json { render json: @resume, status: :created }
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
  end

  def update
    if @resume.update(resume_params)
      redirect_to @resume, notice: "Resume updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: "Resume deleted successfully!"
  end

  def generate_pdf
    # Generate ATS-optimized PDF
    pdf = ResumePdfService.new(@resume).generate
    send_data pdf, filename: "#{@resume.title}_CV.pdf", type: "application/pdf"
  end

  def optimize_ats
    # AI-powered ATS optimization
    result = AtsOptimizationService.new(@resume).optimize
    if result[:success]
      redirect_to @resume, notice: "ATS optimization completed!"
    else
      redirect_to @resume, alert: "ATS optimization failed: " + result[:error]
    end
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:id])
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
