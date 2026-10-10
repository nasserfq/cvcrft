require "test_helper"

# Unauthenticated JSON callers must get 401, not a 302 to the HTML login page.
# Everything under /api uses authenticate_user!, and a redirect there means the
# caller parses a login page as JSON.
class ApiAuthTest < ActionDispatch::IntegrationTest
  test "json request without a session returns 401" do
    get "/api/translation_limit", headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal false, JSON.parse(response.body)["authenticated"]
  end

  test "html request without a session still redirects to login" do
    get "/resumes"

    assert_response :redirect
    assert_match(/login/, response.location)
  end
end
