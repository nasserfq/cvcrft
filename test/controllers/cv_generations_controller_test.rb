require "test_helper"

class CvGenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in @user

    # Create a resume first (might be required for cv_generations access)
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

  # What the pages read from a generation's JSON (cv_generations/new pollers
  # and list); the PDF bytes, the raw AI reply and the backtrace stay server-side.
  CLIENT_METADATA = {
    "pdf_generated" => true, "pdf_size" => 2048, "pdf_filename" => "cv.pdf", "pdf_error" => "late",
    "complete_name" => "Test User", "email" => "test@example.com"
  }.freeze

  def generation_with_full_metadata
    @cv_generation.update!(generated_content: "Tailored summary", metadata: CLIENT_METADATA.merge(
      "pdf_data" => Base64.strict_encode64("%PDF-1.4"), "raw_response" => "{...}",
      "generated_data" => { "summary" => "x" }, "error" => "boom", "error_backtrace" => [ "app/jobs/x.rb:1" ]
    ))
    @cv_generation
  end

  test "show JSON carries only the metadata the pages read" do
    get cv_generation_url(generation_with_full_metadata, format: :json)

    assert_response :success
    assert_equal CLIENT_METADATA, json_response["metadata"]
    assert_equal [ @cv_generation.id, "completed", "Tailored summary" ],
                 json_response.values_at("id", "status", "generated_content")
    assert json_response.key?("job_description")
    assert json_response.key?("created_at")
  end

  test "status JSON carries only the metadata the pages read" do
    get status_cv_generation_url(generation_with_full_metadata, format: :json)

    assert_response :success
    assert_equal CLIENT_METADATA, json_response["metadata"]
    assert_equal "completed", json_response["status"]
    assert_not_includes response.body, "error_backtrace"
  end

  test "index JSON carries only the metadata the pages read" do
    generation_with_full_metadata

    get cv_generations_url(format: :json)

    assert_response :success
    listed = json_response.find { |row| row["id"] == @cv_generation.id }
    assert_equal CLIENT_METADATA, listed["metadata"]
    assert_not_includes response.body, "pdf_data"
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

  def with_new_pdf(body = "new pdf")
    pdf = Tempfile.new([ "cv", ".pdf" ])
    pdf.write(body)
    pdf.flush
    AtsTemplatePdfService.stubs(:generate_pdf).returns({ path: pdf.path, filename: "generated_cv.pdf" })
    yield
  ensure
    pdf&.close!
  end

  def completed_with_pdf
    @cv_generation.update!(resume: @resume, generated_content: "Old summary",
                           metadata: { "pdf_generated" => true, "pdf_data" => Base64.encode64("old pdf") })
    @cv_generation
  end

  test "regenerate replaces the summary and PDF of the generation being viewed" do
    completed_with_pdf
    stub_ai_response({ professional_summary: "Fresh summary for this role." })

    with_new_pdf do
      assert_no_difference -> { CvGeneration.count } do
        post regenerate_cv_generation_url(@cv_generation)
      end
    end

    assert_redirected_to cv_generation_path(@cv_generation)
    @cv_generation.reload
    assert_equal "completed", @cv_generation.status
    assert_equal "Fresh summary for this role.", @cv_generation.generated_content
    assert_equal Base64.encode64("new pdf"), @cv_generation.metadata["pdf_data"]
    assert_not @cv_generation.metadata.key?("regenerating_at")
  end

  test "the show page regenerates with a POST form" do
    get cv_generation_url(completed_with_pdf)

    assert_response :success
    assert_select "form[action='#{regenerate_cv_generation_path(@cv_generation)}'][method='post']"
    assert_select "a[href*='regenerate']", count: 0
  end

  test "a failed regenerate keeps the old summary and PDF and refunds the credit" do
    with_credit_charges do
      completed_with_pdf
      balance = Billing::Credits.balance(@user)
      stub_ai_response({ professional_summary: "Fresh summary for this role." })
      AtsTemplatePdfService.stubs(:generate_pdf).raises(RuntimeError, "prawn broke")

      post regenerate_cv_generation_url(@cv_generation)

      assert_redirected_to cv_generation_path(@cv_generation)
      @cv_generation.reload
      assert_equal "completed", @cv_generation.status
      assert_equal "Old summary", @cv_generation.generated_content
      assert_equal true, @cv_generation.metadata["pdf_generated"]
      assert_equal Base64.encode64("old pdf"), @cv_generation.metadata["pdf_data"]
      assert_not @cv_generation.metadata.key?("regenerating_at")
      assert_equal balance, Billing::Credits.balance(@user)
    end
  end

  test "regenerate while another regenerate holds the generation charges nothing and runs nothing" do
    completed_with_pdf.claim_regeneration!
    Billing::UsageGate.expects(:allow!).never
    CvGeneratorJob.any_instance.expects(:perform).never

    post regenerate_cv_generation_url(@cv_generation)

    assert_redirected_to cv_generation_path(@cv_generation)
  end

  test "regenerate on a generation that isn't completed charges nothing and runs nothing" do
    generation = create_test_cv_generation(@user, resume: @resume, status: "failed")
    Billing::UsageGate.expects(:allow!).never
    CvGeneratorJob.any_instance.expects(:perform).never

    post regenerate_cv_generation_url(generation)

    assert_redirected_to cv_generation_path(generation)
  end

  test "old GET regenerate links only redirect to the generation" do
    completed_with_pdf
    Billing::UsageGate.expects(:allow!).never
    CvGeneratorJob.any_instance.expects(:perform).never

    get download_pdf_cv_generation_url(@cv_generation, regenerate: "true")
    assert_redirected_to cv_generation_path(@cv_generation)

    get view_pdf_cv_generation_url(@cv_generation, regenerate: "true")
    assert_redirected_to cv_generation_path(@cv_generation)
  end

  test "deleting a running generation cancels it first and refunds its credit" do
    with_credit_charges do
      balance = Billing::Credits.balance(@user)
      Billing::UsageGate.allow!(@user, :job_based_generation, key: "delete-key")
      generation = create_test_cv_generation(@user, resume: @resume, metadata: { "overage_key" => "delete-key" })

      delete cv_generation_url(generation, format: :json)

      assert_response :no_content
      assert_not CvGeneration.exists?(generation.id)
      assert_equal balance, Billing::Credits.balance(@user)
    end
  end

  test "retry hands the job only the run's options" do
    generation = create_test_cv_generation(@user, resume: @resume, status: "failed", metadata: {
      "ats_template" => "harvard_classic", "temperature" => 0.5, "pdf_data" => "abc",
      "generated_data" => { "x" => 1 }, "raw_response" => "{}", "error" => "boom", "error_backtrace" => [ "x" ]
    })

    post retry_cv_generation_url(generation)

    assert_redirected_to cv_generation_path(generation)
    assert_equal({ "ats_template" => "harvard_classic", "temperature" => 0.5, "cv_generation_id" => generation.id },
                 CvGeneratorJob.jobs.last["args"][3])
  end

  test "builder export rows are left out of the list and the count" do
    builder = @user.cv_generations.create!(job_description: "CV Builder PDF export", ai_model: "cv_builder",
                                           status: "completed", metadata: { "pdf_generated" => true })

    get cv_generations_url(format: :json)
    assert_not_includes json_response.map { |row| row["id"] }, builder.id

    get count_cv_generations_url(format: :json)
    assert_equal @user.cv_generations.completed.count - 1, json_response["count"]
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
