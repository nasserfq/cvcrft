require "test_helper"

class UserUsageLimitsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  test "job applications have a base of 3 and count from the counter" do
    limits = @user.usage_limits

    assert_equal 3, limits.max_job_applications
    assert_equal 3, limits.remaining_job_applications
    assert limits.free_available?(:job_application)

    3.times { assert limits.consume!(:job_application) }
    limits = @user.reload.usage_limits

    assert_equal 3, limits.job_applications_used
    assert_equal 0, limits.remaining_job_applications
    assert_not limits.free_available?(:job_application)
    assert_not limits.consume!(:job_application)
    assert_equal 3, @user.reload.job_applications_count
  end

  test "an unlimited coupon makes job applications unlimited" do
    UserUsageLimits.any_instance.stubs(:unlimited?).returns(true)
    @user.update_column(:job_applications_count, 10)
    limits = @user.usage_limits

    assert_nil limits.max_job_applications
    assert_nil limits.remaining_job_applications
    assert limits.free_available?(:job_application)
    assert limits.consume!(:job_application)
  end
end
