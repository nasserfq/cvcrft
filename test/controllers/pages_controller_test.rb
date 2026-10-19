require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  VERSION_DATE = Date.iso8601(PrivacyPolicy::VERSION).strftime("%d/%m/%Y")

  test "privacy renders the Arabic policy by default" do
    get privacy_url(locale: "ar")

    assert_response :success
    assert_select "html[lang=ar][dir=rtl]"
    assert_includes response.body, "privacy@cvcrft.com"
    assert_includes response.body, "SDAIA"
    assert_includes response.body, "سدايا"
    assert_includes response.body, VERSION_DATE
    assert_includes response.body, PrivacyPolicy::VERSION
    assert_not_includes response.body, "OpenAI"
  end

  test "privacy renders the English policy for the en locale" do
    get privacy_url(locale: "en")

    assert_response :success
    assert_select "html[lang=en][dir=ltr]"
    assert_select "h2", text: /Transfers outside Saudi Arabia/
    assert_includes response.body, "privacy@cvcrft.com"
    assert_includes response.body, "SDAIA"
    assert_includes response.body, VERSION_DATE
    assert_not_includes response.body, "OpenAI"
  end

  test "privacy names the processors and their locations" do
    get privacy_url(locale: "en")

    %w[netcup Bedrock SES Sentry PostHog Moyasar Jev].each do |name|
      assert_includes response.body, name
    end
  end

  test "privacy links to the terms" do
    get privacy_url(locale: "ar")

    assert_select "a[href=?]", terms_path
  end

  test "terms links to the privacy policy and shows the fixed date" do
    get terms_url

    assert_response :success
    assert_select "main a[href=?]", privacy_path
    assert_includes response.body, VERSION_DATE
    assert_not_includes response.body, "OpenAI"
  end
end
