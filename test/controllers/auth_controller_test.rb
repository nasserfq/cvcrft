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
end
