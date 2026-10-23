require "test_helper"

class CouponServiceTest < ActiveSupport::TestCase
  setup do
    CouponRegistry.reload!
    CouponRedemptionStore.reset!
  end

  test "redeeming an unlimited coupon grants unlimited access" do
    user = users(:one)
    limits_before = user.usage_limits

    assert_equal 5, limits_before.max_summary_translations
    refute limits_before.unlimited?

    coupon = CouponService.redeem(user, "TESTUNLIMITED")

    assert_equal CouponRegistry.digest("TESTUNLIMITED"), coupon.code
    assert coupon.unlimited?

    limits_after = user.usage_limits
    assert limits_after.unlimited?
    assert_nil limits_after.max_summary_translations
    assert limits_after.can_translate_summary?
  end

  test "user cannot redeem same coupon twice" do
    user = users(:one)

    CouponService.redeem(user, "TESTUNLIMITED")

    assert_raises(CouponService::AlreadyRedeemedError) do
      CouponService.redeem(user, "TESTUNLIMITED")
    end
  end

  test "invalid coupon code is rejected" do
    user = users(:one)

    assert_raises(CouponService::InvalidCouponError) do
      CouponService.redeem(user, "NOTREAL")
    end
  end
  test "codes match case-insensitively, and the stored digest is not a code" do
    assert CouponRegistry.find(" testunlimited ")
    assert_nil CouponRegistry.find(CouponRegistry.digest("TESTUNLIMITED"))
  end

  test "a coupon with bonus_credits adds credits once" do
    user = users(:one)
    coupon = ConfigCoupon.new("COACH25", "bonus_credits" => 25)
    CouponRegistry.stubs(:find).with("COACH25").returns(coupon)

    CouponService.redeem(user, "COACH25")
    assert_raises(CouponService::AlreadyRedeemedError) { CouponService.redeem(user, "COACH25") }

    assert_equal Billing::SIGNUP_BONUS + 25, Billing::Credits.balance(user)
  end
end
