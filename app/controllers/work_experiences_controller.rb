class WorkExperiencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume
  before_action :set_work_experience, only: [:update, :destroy]
  
  def create
    @work_experience = @resume.work_experiences.build(work_experience_params)
    
    if @work_experience.save
      # Trigger AI translation if Arabic description is provided
      if @work_experience.arabic_description.present?
        AiTranslationJob.perform_async(@work_experience.id)
      end
      
      redirect_to @resume, notice: 'Work experience added successfully!'
    else
      redirect_to @resume, alert: 'Failed to add work experience.'
    end
  end
  
  def update
    if @work_experience.update(work_experience_params)
      redirect_to @resume, notice: 'Work experience updated successfully!'
    else
      redirect_to @resume, alert: 'Failed to update work experience.'
    end
  end
  
  def destroy
    @work_experience.destroy
    redirect_to @resume, notice: 'Work experience deleted successfully!'
  end
  
  private
  
  def set_resume
    @resume = current_user.resumes.find(params[:resume_id])
  end
  
  def set_work_experience
    @work_experience = @resume.work_experiences.find(params[:id])
  end
  
  def work_experience_params
    params.require(:work_experience).permit(:company, :position, :start_date, :end_date, :arabic_description, :english_description, :ats_keywords)
  end
end
