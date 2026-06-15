require "test_helper"

class CouponServiceTest < ActiveSupport::TestCase
  setup do
    CouponRegistry.reload!
    CouponRedemptionStore.reset!
  end

  test "redeeming NAIF2026 grants unlimited access" do
    user = users(:one)
    limits_before = user.usage_limits

    assert_equal 5, limits_before.max_summary_translations
    refute limits_before.unlimited?

    coupon = CouponService.redeem(user, "NAIF2026")

    assert_equal "NAIF2026", coupon.code
    assert coupon.unlimited?

    limits_after = user.usage_limits
    assert limits_after.unlimited?
    assert_nil limits_after.max_summary_translations
    assert limits_after.can_translate_summary?
  end

  test "user cannot redeem same coupon twice" do
    user = users(:one)

    CouponService.redeem(user, "NAIF2026")

    assert_raises(CouponService::AlreadyRedeemedError) do
      CouponService.redeem(user, "NAIF2026")
    end
  end

  test "invalid coupon code is rejected" do
    user = users(:one)

    assert_raises(CouponService::InvalidCouponError) do
      CouponService.redeem(user, "NOTREAL")
    end
  end
end
