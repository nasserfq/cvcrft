require "test_helper"

class UserRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    # The test cache is a null store, so pretend this is the 6th try.
    ActiveSupport::Cache::NullStore.any_instance.stubs(:increment).returns(6)
  end

  test "a JSON endpoint answers 429 with the message" do
    CouponService.expects(:redeem).never

    post "/api/redeem_coupon", params: { code: "GUESS" }, as: :json

    assert_response :too_many_requests
    assert_equal I18n.t("ux_i18n.rate_limited", locale: :ar), response.parsed_body["error"]
  end

  test "an HTML form goes back with the message" do
    post "/profile/redeem_coupon", params: { code: "GUESS" }, headers: { "HTTP_REFERER" => "/profile" }

    assert_redirected_to "/profile"
    assert_equal I18n.t("ux_i18n.rate_limited", locale: :ar), flash[:alert]
  end
end
