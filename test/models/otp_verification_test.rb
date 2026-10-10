require "test_helper"

class OtpVerificationTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert otp_verifications(:valid_otp).valid?, "valid_otp fixture should be valid"
    assert otp_verifications(:expired_otp).valid?, "expired_otp fixture should be valid"
    assert otp_verifications(:verified_otp).valid?, "verified_otp fixture should be valid"
    assert otp_verifications(:about_to_expire_otp).valid?, "about_to_expire_otp fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save otp without email" do
    otp = OtpVerification.new(
      otp_code: "123456",
      expires_at: 10.minutes.from_now
    )
    assert_not otp.valid?
    assert_includes otp.errors[:email], "can't be blank"
  end

  test "should not save otp with invalid email format" do
    invalid_emails = [ "invalid", "test@", "@example.com", "test.example.com" ]

    invalid_emails.each do |email|
      otp = OtpVerification.new(
        email: email,
        otp_code: "123456",
        expires_at: 10.minutes.from_now
      )
      assert_not otp.valid?, "#{email} should be invalid"
      assert otp.errors[:email].any?
    end
  end

  test "should not save otp without otp_code" do
    otp = OtpVerification.new(
      email: "test@example.com",
      expires_at: 10.minutes.from_now
    )
    assert_not otp.valid?
    assert_includes otp.errors[:otp_code], "can't be blank"
  end

  test "should not save otp with code not exactly 6 characters" do
    invalid_codes = [ "12345", "1234567", "abc", "" ]

    invalid_codes.each do |code|
      otp = OtpVerification.new(
        email: "test@example.com",
        otp_code: code,
        expires_at: 10.minutes.from_now
      )
      assert_not otp.valid?, "#{code} should be invalid"
      assert otp.errors[:otp_code].any?
    end
  end

  test "should save otp with exactly 6 character code" do
    otp = OtpVerification.new(
      email: "test@example.com",
      otp_code: "123456",
      expires_at: 10.minutes.from_now
    )
    assert otp.valid?
  end

  test "should not save otp without expires_at" do
    otp = OtpVerification.new(
      email: "test@example.com",
      otp_code: "123456"
    )
    assert_not otp.valid?
    assert_includes otp.errors[:expires_at], "can't be blank"
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "valid scope returns non-expired non-verified OTPs" do
    valid_otps = OtpVerification.valid
    valid_otps.each do |otp|
      assert otp.expires_at > Time.current, "OTP #{otp.id} should not be expired"
      assert_not otp.verified, "OTP #{otp.id} should not be verified"
    end
  end

  test "expired scope returns only expired OTPs" do
    expired_otps = OtpVerification.expired
    expired_otps.each do |otp|
      assert otp.expires_at <= Time.current, "OTP #{otp.id} should be expired"
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "expired? returns true for expired OTPs" do
    otp = otp_verifications(:expired_otp)
    assert otp.expired?
  end

  test "expired? returns false for non-expired OTPs" do
    otp = otp_verifications(:valid_otp)
    assert_not otp.expired?
  end

  test "verify! returns false for expired OTPs" do
    otp = otp_verifications(:expired_otp)
    assert_not otp.verify!("654321")
  end

  test "verify! returns false for already verified OTPs" do
    otp = otp_verifications(:verified_otp)
    assert_not otp.verify!("111111")
  end

  test "verify! returns false for wrong code" do
    otp = otp_verifications(:valid_otp)
    assert_not otp.verify!("000000")
    otp.reload
    assert_not otp.verified
  end

  test "verify! returns true and sets verified for correct code" do
    otp = otp_verifications(:valid_otp)
    assert otp.verify!("123456")
    otp.reload
    assert otp.verified
  end

  # ============================================
  # CLASS METHOD TESTS
  # ============================================

  test "generate_for creates new OTP for email" do
    email = "newuser@example.com"

    otp = OtpVerification.generate_for(email)

    assert_not_nil otp
    assert_equal email, otp.email
    assert_equal 6, otp.otp_code.length
    assert otp.expires_at > Time.current
    assert_not otp.verified
  end

  test "generate_for destroys old OTPs for same email" do
    email = "duplicate@example.com"

    # Create first OTP
    first_otp = OtpVerification.create!(
      email: email,
      otp_code: "111111",
      expires_at: 10.minutes.from_now
    )
    first_id = first_otp.id

    # Generate new OTP for same email
    new_otp = OtpVerification.generate_for(email)

    # First OTP should be destroyed
    assert_nil OtpVerification.find_by(id: first_id)

    # New OTP should exist
    assert_not_nil OtpVerification.find_by(id: new_otp.id)
  end

  test "generate_for creates code with leading zeros if needed" do
    # Run multiple times to increase chance of getting a code with leading zeros
    100.times do
      otp = OtpVerification.generate_for("leading-zeros-#{rand}@example.com")
      assert_equal 6, otp.otp_code.length
    end
  end

  test "generate_for sets expiration to 10 minutes" do
    otp = OtpVerification.generate_for("expiration@example.com")

    expected_min = 9.minutes.from_now
    expected_max = 11.minutes.from_now

    assert otp.expires_at >= expected_min
    assert otp.expires_at <= expected_max
  end
end
