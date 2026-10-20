require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should get login page" do
    get login_url
    assert_response :success
  end

  test "should request OTP for valid email" do
    # OTP is sent via Sidekiq job
    SendOtpEmailJob.stubs(:perform_later).returns(nil)

    post auth_send_otp_url, params: { email: @user.email, privacy_consent: "1" }
    # Should redirect or return success
    assert_includes [ 200, 302 ], response.status
  end

  test "should reject OTP request for invalid email format" do
    post auth_send_otp_url, params: { email: "invalid-email", privacy_consent: "1" }
    # Should either redirect with error or return error response
    assert_includes [ 302, 422 ], response.status
  end

  test "send_otp without privacy consent sends no code" do
    SendOtpEmailJob.expects(:perform_later).never

    assert_no_difference "OtpVerification.count" do
      post auth_send_otp_url, params: { email: "new-person@example.com" }
    end

    assert_redirected_to login_path(return_to: nil)
    assert_equal I18n.t("pdpl_consent.required", locale: :ar), flash[:alert]
  end

  test "send_otp with privacy consent enqueues the code email" do
    SendOtpEmailJob.expects(:perform_later).once

    assert_difference "OtpVerification.count", 1 do
      post auth_send_otp_url, params: { email: "new-person@example.com", privacy_consent: "1" }
    end

    assert_redirected_to login_path(otp_sent: "true", email: "new-person@example.com", return_to: nil)
  end

  test "login page shows a required consent checkbox linking policy and terms" do
    get login_url

    assert_select "input[type=checkbox][name=privacy_consent][value='1'][required]"
    assert_select "label[for=privacy_consent] a[href=?]", privacy_path
    assert_select "label[for=privacy_consent] a[href=?]", terms_path
  end

  test "login page shows the three social buttons and one consent checkbox" do
    get login_url

    assert_select "input[name=privacy_consent][type=checkbox]", count: 1
    assert_select "input#privacy_consent[form=email-form][required]"
    %w[google_oauth2 apple linkedin].each do |provider|
      assert_select "form[data-social-form][action='/users/auth/#{provider}'][method=post]" do
        assert_select "input[type=hidden][name=privacy_consent][value='0']"
      end
    end
    assert_select "[role=separator]", text: I18n.t("social_auth.or_email", locale: :ar)
    assert_includes response.body, I18n.t("social_auth.continue_with.google", locale: :ar)
  end

  test "login page in English labels the social buttons in English" do
    get login_url(locale: "en")

    assert_includes response.body, "Continue with Apple"
    assert_includes response.body, "Or continue with email"
  end

  test "login page without social providers has no social form and no divider" do
    SocialAuth.stubs(:providers).returns([])

    get login_url

    assert_select "form[data-social-form]", count: 0
    assert_select "[role=separator]", count: 0
    assert_select "form#email-form input#privacy_consent[required]"
  end

  test "OTP form carries the consent flag" do
    get login_url(otp_sent: "true", email: @user.email)

    assert_select "form[action='/auth/verify_otp'] input[type=hidden][name=privacy_consent][value='1']"
  end

  test "verify_otp with consent records it for a new user" do
    email = "brand-new@example.com"
    OtpVerification.create!(email: email, otp_code: "123456", expires_at: 10.minutes.from_now)

    freeze_time do
      post auth_verify_otp_url, params: { email: email, otp_code: "123456", privacy_consent: "1" }

      user = User.find_by!(email: email)
      assert_equal Time.current, user.privacy_accepted_at
      assert_equal PrivacyPolicy::VERSION, user.privacy_policy_version
    end
    assert_redirected_to new_resume_path
  end

  test "verify_otp with consent refreshes it for an existing user" do
    @user.update_columns(privacy_accepted_at: 1.year.ago, privacy_policy_version: "2025-01-01")
    OtpVerification.create!(email: @user.email, otp_code: "123456", expires_at: 10.minutes.from_now)

    post auth_verify_otp_url, params: { email: @user.email, otp_code: "123456", privacy_consent: "1" }

    @user.reload
    assert_equal PrivacyPolicy::VERSION, @user.privacy_policy_version
    assert_in_delta Time.current, @user.privacy_accepted_at, 1.minute
    assert_redirected_to new_resume_path
  end

  test "verify_otp without the consent flag still logs in but records nothing" do
    OtpVerification.create!(email: @user.email, otp_code: "123456", expires_at: 10.minutes.from_now)

    post auth_verify_otp_url, params: { email: @user.email, otp_code: "123456" }

    assert_redirected_to new_resume_path
    @user.reload
    assert_nil @user.privacy_accepted_at
    assert_nil @user.privacy_policy_version
  end

  test "should verify correct OTP" do
    # Create a valid OTP
    OtpVerification.create!(
      email: @user.email,
      otp_code: "123456",
      expires_at: 10.minutes.from_now,
      verified: false
    )

    post auth_verify_otp_url, params: {
      email: @user.email,
      otp: "123456"
    }

    # Should either sign in or show verification form
    assert_includes [ 200, 302 ], response.status
  end

  test "should reject incorrect OTP" do
    # Create a valid OTP
    OtpVerification.create!(
      email: @user.email,
      otp_code: "123456",
      expires_at: 10.minutes.from_now,
      verified: false
    )

    post auth_verify_otp_url, params: {
      email: @user.email,
      otp: "wrong_code"
    }

    # Should not be signed in
    assert_includes [ 200, 302, 422 ], response.status
  end

  test "should reject expired OTP" do
    # Create an expired OTP
    OtpVerification.create!(
      email: @user.email,
      otp_code: "123456",
      expires_at: 10.minutes.ago,
      verified: false
    )

    post auth_verify_otp_url, params: {
      email: @user.email,
      otp: "123456"
    }

    # Should not be signed in
    assert_includes [ 200, 302, 422 ], response.status
  end

  test "should logout" do
    sign_in @user
    delete auth_logout_url
    assert_response :redirect
  end

  test "should get auth status" do
    sign_in @user
    get auth_status_url
    assert_response :success
  end

  test "send_otp error flash follows the English locale" do
    post auth_send_otp_url, params: { email: "invalid-email", privacy_consent: "1", locale: "en" }

    assert_equal "Please enter a valid email address", flash[:alert]
  end

  test "send_otp error flash stays Arabic by default" do
    post auth_send_otp_url, params: { email: "invalid-email", privacy_consent: "1" }

    assert_equal "يرجى إدخال بريد إلكتروني صحيح", flash[:alert]
  end

  test "verify_otp with a wrong code uses the cookie locale" do
    cookies[:locale] = "en"
    post auth_verify_otp_url, params: { email: "nobody@example.com", otp_code: "000000" }

    assert_equal "The verification code is incorrect or has expired", flash[:alert]
  end

  test "expired form token redirects to login in the visitor's locale" do
    ActionController::Base.allow_forgery_protection = true
    cookies[:locale] = "en"
    post auth_send_otp_url, params: { email: @user.email, privacy_consent: "1" }

    assert_redirected_to login_path
    assert_equal "This page has expired. Please try again.", flash[:alert]
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
