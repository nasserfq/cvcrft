class ProfilesController < ApplicationController
  before_action :authenticate_user!
  include PosthogTrackable

  # Global limits
  MAX_CV_BUILDER_GENERATIONS = 5
  MAX_JOB_BASED_GENERATIONS = 5

  def show
    @user = current_user
    @resumes = current_user.resumes.not_drafts.recent.includes(:work_experiences, :skills)
    @drafts = current_user.resumes.drafts.recent
    @cv_generations = current_user.cv_generations.recent
    @ai_translations = current_user.ai_translations.recent.limit(10)
    
    # Count usage for new limits
    cv_builder_used = current_user.cv_generations.where("metadata->>'source' = ?", "cv_builder").count
    job_based_used = current_user.cv_generations.where("metadata->>'source' = ?", "job_description").count
    
    # Calculate stats
    @stats = {
      total_resumes: @resumes.count,
      total_drafts: @drafts.count,
      total_cv_generations: @cv_generations.count,
      total_translations: current_user.ai_translations.count,
      # Translation limits
      remaining_summary_translations: 5 - current_user.ai_translations.where("metadata->>'professional_summary' = ?", "true").count,
      remaining_jobs_translations: 5 - current_user.ai_translations.where("metadata->>'job_descriptions' = ?", "true").count,
      # New generation limits
      cv_builder_used: cv_builder_used,
      cv_builder_remaining: [MAX_CV_BUILDER_GENERATIONS - cv_builder_used, 0].max,
      cv_builder_max: MAX_CV_BUILDER_GENERATIONS,
      job_based_used: job_based_used,
      job_based_remaining: [MAX_JOB_BASED_GENERATIONS - job_based_used, 0].max,
      job_based_max: MAX_JOB_BASED_GENERATIONS
    }
    
    # Track profile view
    track_event("profile_viewed", {
      total_resumes: @stats[:total_resumes],
      total_drafts: @stats[:total_drafts],
      total_cv_generations: @stats[:total_cv_generations],
      cv_builder_remaining: @stats[:cv_builder_remaining],
      job_based_remaining: @stats[:job_based_remaining]
    })
  end

  def destroy
    @user = current_user
    
    # Capture stats before deletion for tracking
    deletion_stats = {
      user_id: @user.id,
      email: @user.email,
      total_resumes: @user.resumes.count,
      total_cv_generations: @user.cv_generations.count,
      total_translations: @user.ai_translations.count,
      account_age_days: ((Time.current - @user.created_at) / 1.day).round
    }
    
    # Track account deletion event BEFORE signing out
    track_event("account_deleted", deletion_stats)
    
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
