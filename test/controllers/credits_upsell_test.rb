require "test_helper"

# A limit hit in an AI feature points at /credits while billing is on, and
# the header shows the credit balance chip.
class CreditsUpsellTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    # Coupon redemptions live in Redis and can leak in from other tests.
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @resume = @user.resumes.create!(complete_name: "Test User",
                                    email: "upsell-#{SecureRandom.hex(4)}@example.com", is_draft: false)
  end

  teardown do
    ENV.delete("BILLING_ENABLED")
    ENV.delete("BILLING_TESTERS")
  end

  test "job-based generation limit includes upgrade_url when billing is on" do
    ENV["BILLING_ENABLED"] = "true"
    UserUsageLimits.any_instance.stubs(:can_generate_job_based?).returns(false)
    drain_credits

    post_generation

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert json["limit_reached"]
    assert_equal credits_path, json["upgrade_url"]
    assert json["upgrade_label"].present?
  end

  test "job-based generation limit has no upgrade_url when billing is off" do
    UserUsageLimits.any_instance.stubs(:can_generate_job_based?).returns(false)

    post_generation

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert json["limit_reached"]
    assert_not json.key?("upgrade_url")
  end

  test "consume failure on generation includes upgrade_url for billing testers" do
    ENV["BILLING_TESTERS"] = @user.email
    UserUsageLimits.any_instance.stubs(:can_generate_job_based?).returns(true)
    UserUsageLimits.any_instance.stubs(:consume!).returns(false)
    drain_credits

    post_generation

    assert_response :too_many_requests
    assert_equal credits_path, JSON.parse(response.body)["upgrade_url"]
  end

  test "cv import limit includes upgrade_url only when billing is on" do
    CvPdfImportService.any_instance.stubs(:parse).returns({ text: "John Doe", language: "en" })
    UserUsageLimits.any_instance.stubs(:consume!).returns(false)

    post cv_import_path, params: { pdf_file: pdf_upload }
    assert_response :too_many_requests
    assert_not JSON.parse(response.body).key?("upgrade_url")

    ENV["BILLING_ENABLED"] = "true"
    drain_credits
    post cv_import_path, params: { pdf_file: pdf_upload }
    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert json["limit_reached"]
    assert_equal credits_path, json["upgrade_url"]
  end

  # Past the free allowance, a use costs 1 credit while billing is on.
  test "job-based generation past the free allowance uses one credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:job_based_generations_count, UserUsageLimits::BASE_JOB_BASED_GENERATIONS)

    post_generation

    assert_response :created
    assert_equal 1, @user.credit_ledger_entries.where(reason: "overage_job_based_generation").count
    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
  end

  test "job-based generation credit is refunded when the job can't be queued" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:job_based_generations_count, UserUsageLimits::BASE_JOB_BASED_GENERATIONS)
    CvGenerationService.any_instance.stubs(:generate_cv).returns({ status: "error" })

    post_generation

    assert_response :unprocessable_entity
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_equal 1, @user.credit_ledger_entries.where(reason: "refund").count
  end

  test "retry of a failed generation past the free allowance uses one credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:job_based_generations_count, UserUsageLimits::BASE_JOB_BASED_GENERATIONS)
    generation = @user.cv_generations.create!(resume: @resume, status: "failed", job_description: "Rails engineer",
                                              ai_model: "test", metadata: { source: "job_description" })
    CvGenerationService.any_instance.stubs(:retry_cv_generation).returns({ message: "queued" })

    post retry_cv_generation_url(generation)

    assert_redirected_to cv_generation_path(generation)
    assert_equal 1, @user.credit_ledger_entries.where(reason: "overage_job_based_generation").count
  end

  test "cv import past the free allowance uses one credit" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    CvPdfImportService.any_instance.stubs(:parse).returns({ text: "John Doe", language: "en" })

    assert_difference -> { CvImportJob.jobs.size }, 1 do
      post cv_import_path, params: { pdf_file: pdf_upload }
    end

    assert_response :success
    assert JSON.parse(response.body)["success"]
    assert_equal 1, @user.credit_ledger_entries.where(reason: "overage_document_ai").count
    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
  end

  test "cv import past the free allowance is blocked while billing is off" do
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    CvPdfImportService.any_instance.stubs(:parse).returns({ text: "John Doe", language: "en" })

    post cv_import_path, params: { pdf_file: pdf_upload }

    assert_response :too_many_requests
    assert_equal 0, @user.credit_ledger_entries.count
  end

  test "a credit-charged generation hands its refund key to the job" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:job_based_generations_count, UserUsageLimits::BASE_JOB_BASED_GENERATIONS)

    post_generation

    key = CvGeneratorJob.jobs.last["args"][3]["overage_key"]
    assert key.present?
    CvGeneratorJob.refund_overage(@user.id, { "overage_key" => key })
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
  end

  test "a free generation passes no refund key" do
    post_generation

    assert_response :created
    assert_not CvGeneratorJob.jobs.last["args"][3].key?("overage_key")
  end

  test "a credit-charged cv import is refunded when its job finally fails" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    CvPdfImportService.any_instance.stubs(:parse).returns({ text: "John Doe", language: "en" })

    post cv_import_path, params: { pdf_file: pdf_upload }

    import_id, key = CvImportJob.jobs.last["args"]
    assert key.present?
    CvImportJob.refund_overage(import_id, key)
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
  end

  test "linkedin import past the free allowance uses one credit and can be refunded" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    LinkedinPdfParserService.any_instance.stubs(:parse).returns("John Doe, Rails engineer")

    post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }

    assert_response :success
    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
    import_id, key = LinkedinImportJob.jobs.last["args"]
    LinkedinImportJob.refund_overage(import_id, key)
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
  end

  test "linkedin import credit is refunded when the PDF can't be parsed" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    LinkedinPdfParserService.any_instance.stubs(:parse).raises(LinkedinPdfParserService::LinkedinPdfParseError, "bad pdf")

    post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }

    assert_response :unprocessable_entity
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
  end

  test "linkedin import with no credits left is blocked with an upgrade link" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    drain_credits

    post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }

    assert_response :too_many_requests
    json = JSON.parse(response.body)
    assert json["limit_reached"]
    assert_equal credits_path, json["upgrade_url"]
  end

  test "header shows the credit chip linking to credits when billing is on" do
    ENV["BILLING_ENABLED"] = "true"

    get resumes_path

    assert_response :success
    assert_select "a[data-testid=header-credit-chip][href=?]", credits_path
    assert_select "a[data-testid=mobile-credit-chip][href=?]", credits_path
    assert_select "[data-testid=header-credit-chip] span", Billing::SIGNUP_BONUS.to_s
  end

  test "header hides the credit chip when billing is off" do
    get resumes_path

    assert_response :success
    assert_select "[data-testid=header-credit-chip]", count: 0
    assert_select "[data-testid=mobile-credit-chip]", count: 0
  end

  private

  # Free allowance used up and no credits to fall back on.
  def drain_credits
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_column(:credit_balance, 0)
  end

  def post_generation
    post cv_generations_url(format: :json), params: {
      cv_generation: { job_description: "Senior Rails engineer", resume_id: @resume.id }
    }
  end

  def pdf_upload
    tempfile = Tempfile.new([ "upsell_cv", ".pdf" ])
    tempfile.write("%PDF-1.4\n%%EOF")
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
  end
end
