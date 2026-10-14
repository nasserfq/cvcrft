require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should have proper HTML structure" do
    get root_url
    assert_select "html"
    assert_select "body"
  end

  test "testers see the AI Coach link in the header and the mobile menu" do
    sign_in users(:one)
    ENV["COACH_TESTERS"] = users(:one).email

    get root_url
    assert_select "a[href='/coach']", 2
  ensure
    ENV.delete("COACH_TESTERS")
  end

  test "other users don't see the AI Coach link" do
    sign_in users(:one)

    get root_url
    assert_select "a[href='/coach']", count: 0
  end

  test "health check returns ok" do
    # Health check doesn't need basic auth
    get "/up"
    assert_response :success
  end
end
