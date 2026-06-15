require "test_helper"

class Api::CouponsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    CouponRegistry.reload!
    CouponRedemptionStore.reset!
  end

  test "should redeem valid coupon" do
    post api_redeem_coupon_url, params: { code: "NAIF2026" }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json.dig("limits", "unlimited")
    assert_nil json.dig("limits", "max_summary")
    assert CouponRedemptionStore.redeemed?(@user.id, "NAIF2026")
  end

  test "should reject blank coupon code" do
    post api_redeem_coupon_url, params: { code: "" }, as: :json

    assert_response :unprocessable_entity
  end

  test "should reject already redeemed coupon" do
    CouponService.redeem(@user, "NAIF2026")

    post api_redeem_coupon_url, params: { code: "NAIF2026" }, as: :json

    assert_response :unprocessable_entity
  end

  test "should require authentication" do
    sign_out @user

    post api_redeem_coupon_url, params: { code: "NAIF2026" }, as: :json

    assert_includes [ 302, 401 ], response.status
  end
end
