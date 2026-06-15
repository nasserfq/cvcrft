require "test_helper"

class Api::CouponsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @coupon = coupons(:promo)
  end

  test "should redeem valid coupon" do
    post api_redeem_coupon_url, params: { code: @coupon.code }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json.dig("limits", "unlimited")
    assert_nil json.dig("limits", "max_summary")
    assert @user.coupon_redemptions.exists?(coupon: @coupon)
  end

  test "should reject blank coupon code" do
    post api_redeem_coupon_url, params: { code: "" }, as: :json

    assert_response :unprocessable_entity
  end

  test "should reject already redeemed coupon" do
    @coupon.redeem_for!(@user)

    post api_redeem_coupon_url, params: { code: @coupon.code }, as: :json

    assert_response :unprocessable_entity
  end

  test "should require authentication" do
    sign_out @user

    post api_redeem_coupon_url, params: { code: @coupon.code }, as: :json

    assert_includes [ 302, 401 ], response.status
  end
end
