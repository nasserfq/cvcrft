require "test_helper"

# I18n.locale is thread-local. The app's locale switch must not outlive the
# request, or the next request on the same thread (e.g. an Administrate page,
# which never sets a locale) renders in the previous visitor's language.
class LocaleIsolationTest < ActionDispatch::IntegrationTest
  test "a request's locale does not leak past the request" do
    get root_url(locale: "ar")

    assert_response :success
    assert_equal "ar", cookies[:locale]
    assert_equal I18n.default_locale, I18n.locale
  end

  test "an admin page after an Arabic request renders in English" do
    get root_url(locale: "ar")
    assert_includes response.body, 'dir="rtl"'

    auth = ActionController::HttpAuthentication::Basic.encode_credentials(ENV["ADMIN_USERNAME"], ENV["ADMIN_PASSWORD"])
    get "/admin/users", headers: { "HTTP_AUTHORIZATION" => auth }

    assert_response :success
    assert_includes response.body, "New user"
    assert_not_includes response.body, "جديد"
  end

  test "the locale cookie still applies to later requests" do
    get root_url(locale: "ar")
    get root_url

    assert_includes response.body, 'dir="rtl"'
  end
end
