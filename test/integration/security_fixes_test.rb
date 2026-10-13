require "test_helper"

# Regression tests for the 2026-10-12 security audit.
class SecurityFixesTest < ActionDispatch::IntegrationTest
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @attacker = users(:one)
    @victim = users(:two)
    @attacker_resume = create_test_resume(@attacker)
    @victim_resume = create_test_resume(@victim, complete_name: "Victim Person")
  end

  test "status of another user's CV generation is not found" do
    generation = create_test_cv_generation(@victim, metadata: { "generated_data" => { "secret" => "x" } })
    sign_in @attacker

    get status_cv_generation_url(generation, format: :json)

    assert_response :not_found
  end

  test "status of own CV generation still works" do
    generation = create_test_cv_generation(@attacker)
    sign_in @attacker

    get status_cv_generation_url(generation, format: :json)

    assert_response :success
    assert_equal generation.id, response.parsed_body["id"]
  end

  test "creating a CV generation from another user's resume is refused" do
    sign_in @attacker

    assert_no_difference -> { CvGeneratorJob.jobs.size } do
      post cv_generations_url(format: :json), params: {
        cv_generation: { job_description: "A job description long enough", resume_id: @victim_resume.id }
      }
    end

    assert_response :not_found
  end

  test "CV generator job will not load another user's resume" do
    job = CvGeneratorJob.new
    job.instance_variable_set(:@user_id, @attacker.id)
    job.instance_variable_set(:@resume_id, @victim_resume.id)

    assert_raises(ActiveRecord::RecordNotFound) { job.send(:owned_resume) }
  end

  test "saving another user's LinkedIn import to a CV is refused" do
    import = LinkedinImport.create!(
      user: @victim, original_filename: "in.pdf", extracted_text: "text", status: "completed",
      parsed_data: { "complete_name" => "Victim Person", "email" => "victim@example.com" }
    )
    sign_in @attacker

    assert_no_difference -> { @attacker.resumes.count } do
      post linkedin_import_save_to_cv_url(import, format: :json)
    end
    assert_nil import.reload.resume_id
  end

  test "summary translation for another user's resume is not queued" do
    sign_in @attacker

    assert_no_difference -> { AiTranslationJob.jobs.size } do
      post api_translate_professional_summary_url(format: :json), params: {
        resume_id: @victim_resume.id, arabic_text: "نص تجريبي للترجمة"
      }
    end
    assert_not_equal 200, response.status
  end

  test "translation job will not write to another user's resume" do
    job = AiTranslationJob.new
    job.instance_variable_set(:@user_id, @attacker.id)
    job.instance_variable_set(:@resume_id, @victim_resume.id)
    job.instance_variable_set(:@options, { professional_summary: true })

    assert_raises(ActiveRecord::RecordNotFound) do
      job.send(:update_resume_with_translation, { english_text: "x" * 80 })
    end
  end

  test "an OTP is burned after too many wrong guesses" do
    otp = OtpVerification.create!(email: @victim.email, otp_code: "123456", expires_at: 10.minutes.from_now)

    OtpVerification::MAX_FAILED_ATTEMPTS.times do |i|
      post auth_verify_otp_url, params: { email: @victim.email, otp_code: format("%06d", i) }
    end
    post auth_verify_otp_url, params: { email: @victim.email, otp_code: "123456" }

    assert_equal OtpVerification::MAX_FAILED_ATTEMPTS, otp.reload.failed_attempts
    assert_not otp.verified?
    get auth_status_url
    assert_equal false, response.parsed_body["authenticated"]
  end

  test "a correct OTP signs in once and cannot be reused" do
    otp = OtpVerification.create!(email: @victim.email, otp_code: "654321", expires_at: 10.minutes.from_now)

    assert otp.verify!("654321")
    assert_not otp.verify!("654321")
  end

  test "return_to only allows same-site paths after login" do
    OtpVerification.create!(email: @attacker.email, otp_code: "111111", expires_at: 10.minutes.from_now)

    post auth_verify_otp_url, params: { email: @attacker.email, otp_code: "111111", return_to: "//evil.example/x" }

    assert_redirected_to new_resume_path
  end

  test "AI quota is not restored by deleting a resume" do
    # Coupon redemptions live in Redis, shared with parallel test workers.
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    limits = UserUsageLimits.new(@attacker)
    UserUsageLimits::BASE_SUMMARY_TRANSLATIONS.times { assert limits.consume!(:summary_translation) }

    assert_not limits.consume!(:summary_translation)
    @attacker_resume.destroy
    assert_not UserUsageLimits.new(@attacker.reload).can_translate_summary?
  end

  test "each PDF render gets its own file even for identical names" do
    first = AtsPdfGenerator.unique_pdf_path
    second = AtsPdfGenerator.unique_pdf_path

    assert_not_equal first, second
  end

  test "PostHog proxy never lets the path change the upstream host" do
    controller = PosthogProxyController.new
    controller.stubs(:request).returns(stub(fullpath: "/ingest.x@2130706433:6379"))

    assert_equal "/.x@2130706433:6379", controller.send(:posthog_path)
  end

  test "debug endpoints are gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/test_sidekiq")
    end
  end
end
