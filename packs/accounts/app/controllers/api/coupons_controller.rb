class Api::CouponsController < ApplicationController
  before_action :authenticate_user!

  include UserRateLimit
  rate_limit_per_user to: 5, within: 10.minutes, only: :redeem, name: "coupon"

  def redeem
    code = params[:code].to_s.strip
    if code.blank?
      return render json: { error: I18n.t("coupons.code_required") }, status: :unprocessable_entity
    end

    coupon = CouponService.redeem(current_user, code)
    limits = current_user.usage_limits.as_json

    track_event("coupon_redeemed", {
      coupon_code: coupon.code,
      unlimited: coupon.unlimited?
    })

    render json: {
      success: true,
      message: I18n.t("coupons.redeemed_success"),
      coupon: coupon.as_json,
      limits: limits
    }
  rescue CouponService::AlreadyRedeemedError
    render json: { error: I18n.t("coupons.already_redeemed") }, status: :unprocessable_entity
  rescue CouponService::InvalidCouponError
    render json: { error: I18n.t("coupons.invalid_or_expired") }, status: :not_found
  end
end
