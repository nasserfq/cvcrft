require "test_helper"

class LoginOtpStepTest < ActionDispatch::IntegrationTest
  test "email input is at least 16px so iOS does not zoom" do
    get login_url

    assert_select "input#email.text-base"
    assert_select "input#email.text-sm", count: 0
  end

  test "code field asks for a numeric one-time code" do
    get login_url(otp_sent: "true", email: "someone@example.com")

    assert_select "input#otp_code[inputmode=numeric][autocomplete=one-time-code][pattern=?]", "[0-9]{6}"
  end

  test "code step can resend to the same address" do
    get login_url(otp_sent: "true", email: "someone@example.com", return_to: "/resumes")

    assert_select "form#resend-otp-form[action='/auth/send_otp'][method=post]" do
      assert_select "input[type=hidden][name=email][value=?]", "someone@example.com"
      assert_select "input[type=hidden][name=return_to][value=?]", "/resumes"
      assert_select "input[type=hidden][name=privacy_consent][value='1']"
      assert_select "input[type=hidden][name=authenticity_token]"
      assert_select "button#resend-otp[type=submit]", text: /#{I18n.t("ux_next.login.resend_code", locale: :ar)}/
    end
  end

  test "resend posts the same send_otp the email form does" do
    SendOtpEmailJob.expects(:perform_later).once

    post auth_send_otp_url, params: { email: "someone@example.com", privacy_consent: "1" }

    assert_redirected_to login_path(otp_sent: "true", email: "someone@example.com", return_to: nil)
  end

  test "code step keeps a hidden, prefilled email step for change email" do
    get login_url(otp_sent: "true", email: "someone@example.com")

    assert_select "#email-step.hidden input#email[value=?]", "someone@example.com"
    assert_select "button#change-email[type=button]"
    assert_select "#email", count: 1
  end

  test "email step shows no OTP controls" do
    get login_url

    assert_select "#email-step.hidden", count: 0
    assert_select "#otp-step", count: 0
    assert_select "#resend-otp", count: 0
  end
end
