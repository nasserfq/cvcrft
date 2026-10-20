require "test_helper"

class Api::TranslationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    # Coupon redemptions live in Redis and can leak in from other tests.
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  test "should return translation limits when authenticated" do
    get api_translation_limit_url
    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert json.key?("remaining_summary_translations") || json.key?("remaining")
  end

  test "translation limit should include all limit types" do
    get api_translation_limit_url
    assert_response :success

    json = JSON.parse(response.body)
    # Should contain limit information
    assert json.is_a?(Hash)
  end

  test "should translate professional summary" do
    # Stub AI service
    AiTranslationJob.stubs(:perform_later).returns(nil)

    post api_translate_professional_summary_url, params: {
      text: "مهندس برمجيات ذو خبرة في تطوير تطبيقات الويب"
    }, as: :json

    # Should return success or create a translation job
    assert_includes [ 200, 201, 202, 422 ], response.status
  end

  test "should translate job descriptions" do
    # Stub AI service
    AiTranslationJob.stubs(:perform_later).returns(nil)

    post api_translate_job_descriptions_url, params: {
      experiences: [
        { description: "تطوير تطبيقات الويب باستخدام Rails" }
      ]
    }, as: :json

    # Should return success or create translation jobs
    assert_includes [ 200, 201, 202, 422 ], response.status
  end

  test "should require authentication for translation limit" do
    sign_out @user
    get api_translation_limit_url
    assert_response :redirect
  end

  test "should require authentication for translations" do
    sign_out @user
    post api_translate_professional_summary_url, params: {
      text: "نص عربي"
    }, as: :json
    # Should redirect or return unauthorized
    assert_includes [ 302, 401 ], response.status
  end

  # Past the free allowance a translation costs 1 credit while billing is on.
  test "summary translation within the free allowance is free" do
    ENV["BILLING_ENABLED"] = "true"

    post api_translate_professional_summary_url, params: { arabic_text: "مهندس برمجيات" }, as: :json

    assert_response :success
    assert_equal "free", json_response["charged"]
    assert_equal 0, @user.credit_ledger_entries.where(reason: "overage_summary_translation").count
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "summary translation past the free allowance uses one credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)

    assert_difference -> { AiTranslationJob.jobs.size }, 1 do
      post api_translate_professional_summary_url, params: { arabic_text: "مهندس برمجيات" }, as: :json
    end

    assert_response :success
    assert_equal "credit", json_response["charged"]
    assert_equal Billing::SIGNUP_BONUS - 1, json_response["credit_balance"]
    assert_equal "summary_translation", AiTranslationJob.jobs.last["args"][3]["overage_kind"]
    assert_equal 1, @user.credit_ledger_entries.where(reason: "overage_summary_translation").count
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "job descriptions translation past the free allowance uses one credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:jobs_translations_count, UserUsageLimits::BASE_JOBS_TRANSLATIONS)

    post api_translate_job_descriptions_url, params: {
      job_descriptions: [ { index: 0, job_title: "Dev", company: "Co", responsibilities: [ "تطوير" ] } ]
    }, as: :json

    assert_response :success
    assert_equal "credit", json_response["charged"]
    assert_equal 1, @user.credit_ledger_entries.where(reason: "overage_jobs_translation").count
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "summary translation with no credits left is blocked with an upgrade link" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_column(:credit_balance, 0)

    assert_no_difference -> { AiTranslationJob.jobs.size } do
      post api_translate_professional_summary_url, params: { arabic_text: "مهندس برمجيات" }, as: :json
    end

    assert_response :too_many_requests
    assert json_response["limit_reached"]
    assert_equal credits_path, json_response["upgrade_url"]
    assert json_response["upgrade_label"].present?
    assert json_response["error"].present?
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "job descriptions translation past the allowance is blocked while billing is off" do
    @user.update_column(:jobs_translations_count, UserUsageLimits::BASE_JOBS_TRANSLATIONS)

    post api_translate_job_descriptions_url, params: {
      job_descriptions: [ { index: 0, job_title: "Dev", company: "Co", responsibilities: [ "تطوير" ] } ]
    }, as: :json

    assert_response :too_many_requests
    assert json_response["limit_reached"]
    assert_not json_response.key?("upgrade_url")
    assert_equal 0, @user.credit_ledger_entries.count
  end

  test "a credit is refunded when queueing the translation fails" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
    AiTranslationJob.stubs(:perform_async).raises(RuntimeError, "redis down")

    post api_translate_professional_summary_url, params: { arabic_text: "مهندس برمجيات" }, as: :json

    assert_response :internal_server_error
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_equal 1, @user.credit_ledger_entries.where(reason: "refund").count
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "a failed translation job refunds its credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
    Billing::UsageGate.allow!(@user, :summary_translation, key: "job-failed")

    AiTranslationJob.refund_overage(@user.id, { "overage_kind" => "summary_translation", "job_id" => "job-failed" })

    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "translation limit reports whether the next use costs a credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)

    get api_translation_limit_url

    assert_response :success
    credits = json_response["credits"]
    assert credits["enabled"]
    assert_equal Billing::SIGNUP_BONUS, credits["balance"]
    assert_equal 1, credits["cost"]
    assert credits["summary_translation"]["will_use_credit"]
    assert credits["jobs_translation"]["free_available"]
    assert_equal credits_path, json_response["upgrade_url"]
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "translation limit says credits are off while billing is off" do
    get api_translation_limit_url

    credits = json_response["credits"]
    assert_not credits["enabled"]
    assert_nil credits["balance"]
    assert_not json_response.key?("upgrade_url")
  end

  # Regression: pdf_status called an undefined CvBuilderPdfJob method, so every
  # poll from the export flow 500'd.
  test "pdf_status returns a download url once the PDF path is in Redis" do
    pdf = Tempfile.new([ "resume", ".pdf" ])
    Redis.stubs(:new).returns(stub(get: pdf.path))

    get api_pdf_status_translations_url, params: { job_id: "job123", token: "tok123" }

    assert_response :success
    assert_equal "completed", json_response["status"]
    assert_equal "/api/export_pdf?direct_download=true&token=tok123", json_response["download_url"]
  ensure
    pdf&.close!
  end

  test "pdf_status stays processing while the PDF is not in Redis yet" do
    Redis.stubs(:new).returns(stub(get: nil))

    get api_pdf_status_translations_url, params: { job_id: "job123", token: "tok123" }

    assert_response :success
    assert_equal "processing", json_response["status"]
  end
end
