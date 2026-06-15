require "test_helper"

class CouponTest < ActiveSupport::TestCase
  test "redeeming unlimited coupon removes all limits" do
    user = users(:one)
    coupon = coupons(:promo)
    limits_before = user.usage_limits

    assert_equal 5, limits_before.max_summary_translations
    refute limits_before.unlimited?

    coupon.redeem_for!(user)

    limits_after = user.reload.usage_limits
    assert limits_after.unlimited?
    assert_nil limits_after.max_summary_translations
    assert_nil limits_after.remaining_summary_translations
    assert limits_after.can_translate_summary?
    assert limits_after.can_generate_cv_builder?
  end

  test "user cannot redeem same coupon twice" do
    user = users(:one)
    coupon = coupons(:promo)

    coupon.redeem_for!(user)

    assert_raises(ActiveRecord::RecordInvalid) do
      coupon.redeem_for!(user)
    end
  end
end
