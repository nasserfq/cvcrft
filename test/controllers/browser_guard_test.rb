require "test_helper"

class BrowserGuardTest < ActionDispatch::IntegrationTest
  META_CRAWLER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/601.2.4 (KHTML, like Gecko) " \
    "Version/9.0.1 Safari/601.2.4 facebookexternalhit/1.1 Facebot Twitterbot/1.0"
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/601.2.4 (KHTML, like Gecko) " \
    "Version/9.0.1 Safari/601.2.4"
  IOS_17_1 = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
    "Version/17.1.2 Mobile/15E148 Safari/604.1"
  IOS_16_3 = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
    "Version/16.3 Mobile/15E148 Safari/604.1"
  MIUI = "Mozilla/5.0 (Linux; U; Android 13; ar-sa; 2201117TG Build/TKQ1.221114.001) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Version/4.0 Chrome/112.0.5615.136 Mobile Safari/537.36 XiaoMi/MiuiBrowser/14.4.0-g"

  test "Meta's link-preview crawler gets the landing page" do
    get root_url, headers: { "User-Agent" => META_CRAWLER }
    assert_response :success
  end

  test "iOS 17.1 Safari and Chrome 112 get the landing page" do
    [ IOS_17_1, MIUI ].each do |user_agent|
      get root_url, headers: { "User-Agent" => user_agent }
      assert_response :success, user_agent
    end
  end

  test "browsers older than the styles support get the unsupported browser page" do
    [ OLD_SAFARI, IOS_16_3 ].each do |user_agent|
      get root_url, headers: { "User-Agent" => user_agent }
      assert_response :not_acceptable, user_agent
    end
  end
end
