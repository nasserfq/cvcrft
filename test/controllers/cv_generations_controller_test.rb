require "test_helper"

class CvGenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in @user

    # Create a resume first (might be required for cv_generations access)
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @resume = Resume.create!(
      user: @user,
      complete_name: "Test User",
      email: "cv-gen-test-#{SecureRandom.hex(4)}@example.com",
      is_draft: false
    )

    @cv_generation = CvGeneration.create!(
      user: @user,
      job_description: "Looking for a software engineer with experience in web development and Ruby on Rails",
      ai_model: "gpt-4",
      status: "completed"
    )
  end

  test "new without a completed resume sends the user to the resume builder with a message" do
    @user.resumes.update_all(is_draft: true)
    get new_cv_generation_url
    assert_redirected_to new_resume_path
    follow_redirect! while response.redirect?
    assert_select "[role=alert]", text: I18n.t("resume.need_resume_for_job", locale: :ar)
  end

  test "should redirect to login when not authenticated for index" do
    sign_out @user
    get cv_generations_url
    assert_response :redirect
  end

  test "should redirect to login when not authenticated for new" do
    sign_out @user
    get new_cv_generation_url
    assert_response :redirect
  end

  test "should get index when authenticated" do
    get cv_generations_url
    # May redirect to resumes or show index depending on application logic
    assert_includes [ 200, 302 ], response.status
  end

  test "should get new when authenticated" do
    get new_cv_generation_url
    assert_response :success
  end

  test "should show cv_generation" do
    get cv_generation_url(@cv_generation)
    assert_response :success
  end

  test "should not show other user's cv_generation" do
    other_cv = CvGeneration.create!(
      user: @other_user,
      job_description: "Another job description that is long enough for validation requirements",
      ai_model: "gpt-4",
      status: "completed"
    )
    get cv_generation_url(other_cv)
    # Should redirect or return not found
    assert_includes [ 302, 404 ], response.status
  end

  test "should create cv_generation" do
    CvGeneratorJob.stubs(:perform_async).returns(nil)

    assert_difference("CvGeneration.count") do
      post cv_generations_url, params: {
        cv_generation: {
          job_description: "New job description for testing that meets minimum length requirements",
          resume_id: @resume.id,
          ats_template: "minimalist_real_estate"
        }
      }
    end

    created = CvGeneration.order(:id).last
    assert_equal "minimalist_real_estate", created.metadata["ats_template"]
  end

  test "create without a saved CV redirects back with a message and spends no credit" do
    UserUsageLimits.any_instance.expects(:consume!).never
    CvGeneratorJob.expects(:perform_async).never

    assert_no_difference [ "CvGeneration.count", "Resume.count", -> { @user.reload.job_based_generations_count.to_i } ] do
      post cv_generations_url, params: {
        cv_generation: { job_description: "New job description for testing that meets minimum length requirements", resume_id: "" }
      }
    end

    assert_redirected_to new_cv_generation_path
    assert_equal I18n.t("cv_generation.choose_resume", locale: :ar), flash[:alert]
  end

  test "create without a saved CV as JSON is refused with 422 and spends no credit" do
    UserUsageLimits.any_instance.expects(:consume!).never
    CvGeneratorJob.expects(:perform_async).never

    assert_no_difference [ "CvGeneration.count", "Resume.count", -> { @user.reload.job_based_generations_count.to_i } ] do
      post cv_generations_url(format: :json, locale: "en"), params: {
        cv_generation: { job_description: "New job description for testing that meets minimum length requirements" }
      }
    end

    assert_response :unprocessable_entity
    assert_equal({ "error" => "Choose one of your CVs first." }, response.parsed_body)
  end

  test "retry of a generation with no saved CV is refused before spending a credit" do
    @cv_generation.update!(status: "failed")
    UserUsageLimits.any_instance.expects(:consume!).never
    CvGeneratorJob.expects(:perform_async).never

    post retry_cv_generation_url(@cv_generation)

    assert_redirected_to new_cv_generation_path
    assert_equal I18n.t("cv_generation.choose_resume", locale: :ar), flash[:alert]
  end

  test "resume_draft of a generation with no saved CV is refused before spending a credit" do
    UserUsageLimits.any_instance.expects(:consume!).never
    CvGeneratorJob.expects(:perform_async).never

    post resume_draft_cv_generation_url(@cv_generation, format: :json, locale: "en")

    assert_response :unprocessable_entity
    assert_equal({ "success" => false, "error" => "Choose one of your CVs first." }, response.parsed_body)
  end

  test "should get status as json" do
    get status_cv_generation_url(@cv_generation), as: :json
    assert_response :success
  end

  # ============================================
  # STATE TRANSITIONS
  # ============================================

  JOB = "Looking for a software engineer with experience in web development and Ruby on Rails".freeze

  def with_credit_charges
    ENV["BILLING_ENABLED"] = "true"
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @user.update_column(:job_based_generations_count, UserUsageLimits::BASE_JOB_BASED_GENERATIONS)
    yield
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "create hands the job the id of the generation it created" do
    post cv_generations_url(format: :json), params: { cv_generation: { job_description: JOB, resume_id: @resume.id } }

    assert_response :created
    created = CvGeneration.order(:id).last
    assert_equal created.id, CvGeneratorJob.jobs.last["args"][3]["cv_generation_id"]
  end

  test "create whose job can't be queued fails the generation and refunds the credit" do
    with_credit_charges do
      balance = Billing::Credits.balance(@user)
      CvGeneratorJob.stubs(:perform_async).raises(RuntimeError, "redis down")

      assert_raises(RuntimeError) do
        post cv_generations_url(format: :json), params: { cv_generation: { job_description: JOB, resume_id: @resume.id } }
      end

      assert_equal "failed", CvGeneration.order(:id).last.status
      assert_equal balance, Billing::Credits.balance(@user)
      assert_equal 1, @user.credit_ledger_entries.where(reason: "refund").count
    end
  end

  test "cancel stops a running generation and refunds its credit" do
    with_credit_charges do
      balance = Billing::Credits.balance(@user)
      Billing::UsageGate.allow!(@user, :job_based_generation, key: "cancel-key")
      generation = create_test_cv_generation(@user, resume: @resume, metadata: { "overage_key" => "cancel-key" })

      post cancel_cv_generation_url(generation)
      post cancel_cv_generation_url(generation)

      assert_redirected_to cv_generation_path(generation)
      assert_equal "cancelled", generation.reload.status
      assert_equal balance, Billing::Credits.balance(@user)
      assert_equal 1, @user.credit_ledger_entries.where(reason: "refund").count
    end
  end

  test "regenerate PDF updates the generation being viewed" do
    @cv_generation.update!(resume: @resume, metadata: { "pdf_generated" => true, "pdf_data" => Base64.encode64("old pdf") })
    stub_ai_response({ professional_summary: "Fresh summary for this role." })
    pdf = Tempfile.new([ "cv", ".pdf" ])
    pdf.write("new pdf")
    pdf.flush
    AtsTemplatePdfService.stubs(:generate_pdf).returns({ path: pdf.path, filename: "generated_cv.pdf" })

    assert_no_difference -> { CvGeneration.count } do
      get view_pdf_cv_generation_url(@cv_generation, regenerate: "true")
    end

    assert_response :success
    assert_equal "new pdf", response.body
    assert_equal "completed", @cv_generation.reload.status
    assert_equal "Fresh summary for this role.", @cv_generation.generated_content
  ensure
    pdf&.close!
  end

  test "regenerate on a generation that isn't completed charges nothing and runs nothing" do
    generation = create_test_cv_generation(@user, resume: @resume, status: "failed")
    Billing::UsageGate.expects(:allow!).never
    CvGeneratorJob.any_instance.expects(:perform).never

    get download_pdf_cv_generation_url(generation, regenerate: "true")

    assert_redirected_to cv_generation_path(generation)
  end

  %w[processing completed].each do |status|
    test "save_draft refuses a #{status} generation" do
      generation = create_test_cv_generation(@user, resume: @resume, status: status)

      post save_draft_cv_generation_url(generation, format: :json), params: { job_description: JOB }

      assert_response :unprocessable_entity
      assert_equal false, response.parsed_body["success"]
      assert_equal status, generation.reload.status
      assert_not generation.is_draft
    end
  end

  test "preview_resume shows the resume's own PDF" do
    get preview_resume_cv_generation_url(@resume)

    assert_redirected_to generate_pdf_resume_path(@resume, preview: "true")
  end

  test "preview_resume refuses another user's resume" do
    other = Resume.create!(user: @other_user, complete_name: "Other", email: "other-#{SecureRandom.hex(4)}@example.com")

    get preview_resume_cv_generation_url(other)

    assert_response :not_found
  end
end
