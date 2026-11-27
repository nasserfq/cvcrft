require "test_helper"
require "capybara/selenium/driver"

# Capybara 3.40 resets the session with Storage.clearDataForOrigin(origin: "*"),
# which Chrome 158 rejects as an invalid URL. Clear cookies and storage for
# every origin with calls Chrome still accepts.
module ChromeResetWildcardOriginFix
  private

  def execute_cdp(cmd, params = {})
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    super("Storage.clearDataForOrigin", params.merge(origin: Capybara.current_session.server_url.to_s)) if Capybara.current_session.server
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetWildcardOriginFix)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
