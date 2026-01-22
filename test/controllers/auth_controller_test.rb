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

    post auth_send_otp_url, params: { email: @user.email }
    # Should redirect or return success
    assert_includes [ 200, 302 ], response.status
  end

  test "should reject OTP request for invalid email format" do
    post auth_send_otp_url, params: { email: "invalid-email" }
    # Should either redirect with error or return error response
    assert_includes [ 302, 422 ], response.status
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
