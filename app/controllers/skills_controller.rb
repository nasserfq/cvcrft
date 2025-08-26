class SkillsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume
  before_action :set_skill, only: [:update, :destroy]
  
  def create
    @skill = @resume.skills.build(skill_params)
    
    if @skill.save
      redirect_to @resume, notice: 'Skill added successfully!'
    else
      redirect_to @resume, alert: 'Failed to add skill.'
    end
  end
  
  def update
    if @skill.update(skill_params)
      redirect_to @resume, notice: 'Skill updated successfully!'
    else
      redirect_to @resume, alert: 'Failed to update skill.'
    end
  end
  
  def destroy
    @skill.destroy
    redirect_to @resume, notice: 'Skill deleted successfully!'
  end
  
  private
  
  def set_resume
    @resume = current_user.resumes.find(params[:resume_id])
  end
  
  def set_skill
    @skill = @resume.skills.find(params[:id])
  end
  
  def skill_params
    params.require(:skill).permit(:name, :level, :category)
  end
end
