require "test_helper"

class SocialSignInControllerTest < ActionDispatch::IntegrationTest
  setup do
    # In mock mode OmniAuth answers the request phase itself, so nothing loads
    # the (lazy) routes, and Devise's failure hook needs their mappings.
    Rails.application.reload_routes_unless_loaded
    OmniAuth.config.test_mode = true
    @email = "social-#{SecureRandom.hex(4)}@example.com"
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid: "google-#{SecureRandom.hex(4)}",
      info: { email: @email, name: "Social Person" },
      extra: { raw_info: { email_verified: true } }
    )
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:google_oauth2)
  end

  test "Google sign-in with consent creates the user and lands on return_to" do
    assert_difference [ "User.count", "UserIdentity.count" ], 1 do
      post "/users/auth/google_oauth2", params: { privacy_consent: "1", return_to: "/resumes" }
      follow_redirect!
    end

    assert_redirected_to "/resumes"
    user = User.find_by(email: @email)
    assert_not_nil user.privacy_accepted_at
    assert_equal PrivacyPolicy::VERSION, user.privacy_policy_version
    assert_equal I18n.t("ux_i18n.auth.signed_in", locale: :ar), flash[:notice]

    get "/auth/status"
    assert json_response["authenticated"]
  end

  test "Google sign-in without consent creates nothing and asks for it" do
    assert_no_difference [ "User.count", "UserIdentity.count" ] do
      post "/users/auth/google_oauth2", params: { return_to: "/resumes" }
      follow_redirect!
    end

    assert_redirected_to login_path(return_to: "/resumes")
    assert_equal I18n.t("pdpl_consent.required", locale: :ar), flash[:alert]
  end

  test "an off-site return_to falls back to the CV builder" do
    post "/users/auth/google_oauth2", params: { privacy_consent: "1", return_to: "//evil.com" }
    follow_redirect!

    assert_redirected_to new_resume_path
  end

  test "an unverified email is refused with its own message" do
    OmniAuth.config.mock_auth[:google_oauth2].extra.raw_info.email_verified = false

    assert_no_difference "User.count" do
      post "/users/auth/google_oauth2", params: { privacy_consent: "1" }
      follow_redirect!
    end

    assert_redirected_to login_path
    assert_equal I18n.t("social_auth.errors.email_unverified", locale: :ar), flash[:alert]
  end

  test "a provider failure returns to the login page" do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

    post "/users/auth/google_oauth2", params: { privacy_consent: "1", return_to: "/resumes" }
    follow_redirect!

    assert_redirected_to login_path(return_to: "/resumes")
    assert_equal I18n.t("social_auth.failed", locale: :ar), flash[:alert]
  end

  test "Apple's form_post is bounced to the callback as a GET with only Apple's fields" do
    forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post "/auth/apple/form_post", params: { code: "c", state: "s", id_token: "t", user: '{"name":{}}', extra: "x" }

    assert_response :see_other
    location = URI(response.location)
    assert_equal "/users/auth/apple/callback", location.path
    query = Rack::Utils.parse_query(location.query)
    assert_equal({ "code" => "c", "state" => "s", "id_token" => "t", "user" => '{"name":{}}' }, query)
  ensure
    ActionController::Base.allow_forgery_protection = forgery
  end
end
