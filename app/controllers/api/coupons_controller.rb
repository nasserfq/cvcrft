class Api::CouponsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [ :redeem ]

  def redeem
    code = params[:code].to_s.strip
    if code.blank?
      return render json: { error: I18n.t("coupons.code_required") }, status: :unprocessable_entity
    end

    coupon = Coupon.find_by(code: code.upcase)
    unless coupon&.redeemable?
      return render json: { error: I18n.t("coupons.invalid_or_expired") }, status: :not_found
    end

    if current_user.coupon_redemptions.exists?(coupon: coupon)
      return render json: { error: I18n.t("coupons.already_redeemed") }, status: :unprocessable_entity
    end

    coupon.redeem_for!(current_user)

    limits = current_user.usage_limits.as_json

    track_event("coupon_redeemed", {
      coupon_code: coupon.code,
      bonus_summary: coupon.bonus_summary_translations,
      bonus_jobs: coupon.bonus_jobs_translations,
      bonus_cv_builder: coupon.bonus_cv_builder_generations,
      bonus_job_based: coupon.bonus_job_based_generations
    })

    render json: {
      success: true,
      message: I18n.t("coupons.redeemed_success"),
      coupon: {
        code: coupon.code,
        bonus_summary_translations: coupon.bonus_summary_translations,
        bonus_jobs_translations: coupon.bonus_jobs_translations,
        bonus_cv_builder_generations: coupon.bonus_cv_builder_generations,
        bonus_job_based_generations: coupon.bonus_job_based_generations
      },
      limits: limits
    }
  rescue ActiveRecord::RecordInvalid
    render json: { error: I18n.t("coupons.invalid_or_expired") }, status: :unprocessable_entity
  end
end
