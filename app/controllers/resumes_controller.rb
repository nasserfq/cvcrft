class ResumesController < ApplicationController
  # before_action :authenticate_user!  # Temporarily disabled
  before_action :set_resume, only: [:show, :edit, :update, :destroy, :generate_pdf, :optimize_ats]
  
  def index
    # @resumes = current_user.resumes.recent  # Temporarily disabled
    @resumes = Resume.all.limit(10)  # Show all resumes temporarily
  end
  
  def show
    @work_experiences = @resume.work_experiences.chronological
    @skills = @resume.skills.group_by(&:category)
    @ai_translations = @resume.ai_translations.recent
  end
  
  def new
    @resume = Resume.new  # Temporarily disabled user association
  end
  
  def create
    @resume = Resume.new(resume_params)  # Temporarily disabled user association
    if @resume.save
      respond_to do |format|
        format.html { redirect_to @resume, notice: 'Resume created successfully!' }
        format.json { render json: @resume, status: :created }
      end
    else
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
      redirect_to @resume, notice: 'Resume updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @resume.destroy
    redirect_to resumes_path, notice: 'Resume deleted successfully!'
  end
  
  def generate_pdf
    # Generate ATS-optimized PDF
    pdf = ResumePdfService.new(@resume).generate
    send_data pdf, filename: "#{@resume.title}_CV.pdf", type: 'application/pdf'
  end
  
  def optimize_ats
    # AI-powered ATS optimization
    result = AtsOptimizationService.new(@resume).optimize
    if result[:success]
      redirect_to @resume, notice: 'ATS optimization completed!'
    else
      redirect_to @resume, alert: 'ATS optimization failed: ' + result[:error]
    end
  end
  
  private
  
  def set_resume
    @resume = Resume.find(params[:id])  # Temporarily disabled user association
  end
  
  def resume_params
    params.require(:resume).permit(
      :complete_name, :email, :phone_number, :city, :country, 
      :professional_summary, :professional_summary_english,
      educations_attributes: [:degree, :institution, :start_date, :end_date, :gpa, :is_current],
      work_experiences_attributes: [:job_title, :company, :start_date, :end_date, :is_current, responsibilities: []],
      skills_attributes: [:category, skill_names: []],
      certifications_attributes: [:name, :organization, :date],
      languages_attributes: [:language, :proficiency]
    )
  end
end
