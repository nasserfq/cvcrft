class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @resumes = current_user.resumes.not_drafts.recent.includes(:work_experiences, :skills)
    @drafts = current_user.resumes.drafts.recent
    @cv_generations = current_user.cv_generations.recent
    @ai_translations = current_user.ai_translations.recent.limit(10)
    
    # Calculate stats
    @stats = {
      total_resumes: @resumes.count,
      total_drafts: @drafts.count,
      total_cv_generations: @cv_generations.count,
      total_translations: current_user.ai_translations.count,
      remaining_summary_translations: 5 - current_user.ai_translations.where("metadata->>'professional_summary' = ?", "true").count,
      remaining_jobs_translations: 5 - current_user.ai_translations.where("metadata->>'job_descriptions' = ?", "true").count
    }
  end

  def destroy
    @user = current_user
    
    # Sign out first
    sign_out(@user)
    
    # Delete all associated data
    @user.resumes.destroy_all
    @user.cv_generations.destroy_all
    @user.ai_translations.destroy_all
    
    # Delete the user
    @user.destroy
    
    redirect_to root_path, notice: "تم حذف حسابك بنجاح. نأسف لرؤيتك تغادر!"
  end
end
