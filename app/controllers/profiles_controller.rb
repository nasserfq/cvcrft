class ProfilesController < ApplicationController
  before_action :authenticate_user!
  include PosthogTrackable

  def show
    @user = current_user
    @resumes = current_user.resumes.not_drafts.recent.includes(:work_experiences, :skills)
    @drafts = current_user.resumes.drafts.recent
    @cv_generations = current_user.cv_generations.recent
    @ai_translations = current_user.ai_translations.recent.limit(10)

    limits = current_user.usage_limits

    @stats = {
      unlimited: limits.unlimited?,
      total_resumes: @resumes.count,
      total_drafts: @drafts.count,
      total_cv_generations: @cv_generations.count,
      total_translations: current_user.ai_translations.count,
      remaining_summary_translations: limits.remaining_summary_translations,
      summary_translations_max: limits.max_summary_translations,
      remaining_jobs_translations: limits.remaining_jobs_translations,
      jobs_translations_max: limits.max_jobs_translations,
      cv_builder_used: limits.cv_builder_generations_used,
      cv_builder_remaining: limits.remaining_cv_builder_generations,
      cv_builder_max: limits.max_cv_builder_generations,
      job_based_used: limits.job_based_generations_used,
      job_based_remaining: limits.remaining_job_based_generations,
      job_based_max: limits.max_job_based_generations
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

  def redeem_coupon
    code = params[:code].to_s.strip
    if code.blank?
      redirect_to profile_path, alert: t("coupons.code_required") and return
    end

    coupon = CouponService.redeem(current_user, code)

    track_event("coupon_redeemed", { coupon_code: coupon.code, unlimited: coupon.unlimited? })

    redirect_to profile_path, notice: t("coupons.redeemed_success")
  rescue CouponService::AlreadyRedeemedError
    redirect_to profile_path, alert: t("coupons.already_redeemed")
  rescue CouponService::InvalidCouponError
    redirect_to profile_path, alert: t("coupons.invalid_or_expired")
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
