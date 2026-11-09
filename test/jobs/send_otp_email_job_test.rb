require "test_helper"

class SendOtpEmailJobTest < ActiveJob::TestCase
  setup do
    @otp = OtpVerification.create!(email: "user@example.com", otp_code: "123456", expires_at: 10.minutes.from_now)
  end

  test "sends a usable code" do
    SeeraEmail.expects(:otp).with("123456").returns(stub(deliver_to: true))

    SendOtpEmailJob.perform_now(@otp.id)
  end

  test "skips a code that was used, expired or burned before the job ran" do
    SeeraEmail.expects(:otp).never

    @otp.update!(verified: true)
    SendOtpEmailJob.perform_now(@otp.id)

    @otp.update!(verified: false, expires_at: 1.minute.ago)
    SendOtpEmailJob.perform_now(@otp.id)

    @otp.update!(expires_at: 10.minutes.from_now, failed_attempts: OtpVerification::MAX_FAILED_ATTEMPTS)
    SendOtpEmailJob.perform_now(@otp.id)
  end

  test "skips a code replaced by a newer one" do
    SeeraEmail.expects(:otp).never

    SendOtpEmailJob.perform_now(@otp.id + 1_000)
  end
end
