require "test_helper"

class UserUsageLimitsTest < ActiveSupport::TestCase
  setup do
    CouponRegistry.reload!
    CouponRedemptionStore.reset!
    @user = users(:one)
  end

  test "consume! records one use while allowance is left" do
    assert @user.usage_limits.consume!(:summary_translation)
    assert_equal 1, @user.reload.summary_translations_count
  end

  test "consume! records nothing once the allowance is used up" do
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)

    refute @user.usage_limits.consume!(:summary_translation)
    assert_equal UserUsageLimits::BASE_SUMMARY_TRANSLATIONS, @user.reload.summary_translations_count
  end

  test "consume! reads coupons before taking the row lock" do
    locked = false
    reads = []
    @user.singleton_class.prepend(Module.new do
      define_method(:with_lock) do |*args, &block|
        locked = true
        super(*args, &block)
      ensure
        locked = false
      end
    end)
    CouponRedemptionStore.stubs(:redeemed_codes_for).with { reads << locked }.returns([])

    assert @user.usage_limits.consume!(:summary_translation)
    assert_not_empty reads
    assert_equal [ false ], reads.uniq
  end

  test "consume! keeps an unlimited coupon past the base allowance" do
    CouponService.redeem(@user, "TESTUNLIMITED")
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)

    assert @user.usage_limits.consume!(:summary_translation)
    assert_equal UserUsageLimits::BASE_SUMMARY_TRANSLATIONS + 1, @user.reload.summary_translations_count
  end

  test "a coupon redeemed after consume! still counts" do
    limits = @user.usage_limits
    limits.consume!(:summary_translation)

    CouponService.redeem(@user, "TESTUNLIMITED")

    assert limits.unlimited?
  end
end
