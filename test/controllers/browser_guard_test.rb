require "test_helper"

class BrowserGuardTest < ActionDispatch::IntegrationTest
  META_CRAWLER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/601.2.4 (KHTML, like Gecko) " \
    "Version/9.0.1 Safari/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0"
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/601.2.4 (KHTML, like Gecko) " \
    "Version/9.0.1 Safari/601.2.4"

  test "Meta's link-preview crawler gets the landing page" do
    get root_url, headers: { "User-Agent" => META_CRAWLER }
    assert_response :success
  end

  test "old browsers still get the unsupported browser page" do
    get root_url, headers: { "User-Agent" => OLD_SAFARI }
    assert_response :not_acceptable
  end
end
