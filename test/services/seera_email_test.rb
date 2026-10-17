require "test_helper"

class SeeraEmailTest < ActiveSupport::TestCase
  test "otp email has both subjects and the code in Arabic then English" do
    email = SeeraEmail.otp("482913")

    assert_equal "رمز الدخول إلى سيرة | Your Seera login code", email.subject
    [ email.html, email.text ].each do |body|
      assert_operator body.index("رمز الدخول الخاص بك"), :<, body.index("Your login code")
      assert_equal 2, body.scan("482913").size
    end
    assert_includes email.html, 'dir="rtl" lang="ar"'
    assert_includes email.html, 'dir="ltr" lang="en"'
  end

  test "welcome email escapes the name" do
    email = SeeraEmail.welcome("<b>Sara</b>")

    assert_equal "أهلاً بك في سيرة | Welcome to Seera", email.subject
    assert_includes email.html, "&lt;b&gt;Sara&lt;/b&gt;"
    assert_not_includes email.html, "<b>Sara</b>"
  end

  test "every email has its own Arabic copy" do
    %w[otp welcome notification].each do |kind|
      ar, en = SeeraEmail.public_send(*[ kind, ("123456" if kind == "otp"), ("Sara" if kind == "welcome") ].compact).subject.split(" | ")
      assert_match(/\p{Arabic}/, ar)
      assert_no_match(/\p{Arabic}/, en)
    end
  end

  test "the otp job sends the bilingual email through SES" do
    sent = nil
    ses = Object.new
    ses.define_singleton_method(:send_email) { |**args| sent = args }

    AmazonSesService.stubs(:new).returns(ses)
    otp = OtpVerification.create!(email: "user@example.com", otp_code: "123456", expires_at: 10.minutes.from_now)
    SendOtpEmailJob.perform_now(otp.id)

    assert_equal "user@example.com", sent[:to]
    assert_equal "رمز الدخول إلى سيرة | Your Seera login code", sent[:subject]
    assert_includes sent[:body], "123456"
    assert_includes sent[:text], "123456"
  end
end
