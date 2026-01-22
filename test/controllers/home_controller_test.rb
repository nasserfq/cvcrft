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

  test "health check returns ok" do
    # Health check doesn't need basic auth
    get "/up"
    assert_response :success
  end
end
