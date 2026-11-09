require "test_helper"

# While AiCircuit says the AI is busy, every action that starts AI work is
# refused before anything is charged; everything else keeps working.
class AiCapacityTest < ActionDispatch::IntegrationTest
  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @user = users(:user_with_resumes)
    sign_in @user
    AiCircuit.stubs(:busy?).returns(true)
    Billing::UsageGate.expects(:allow!).never
    UserUsageLimits.any_instance.expects(:consume!).never
    Sidekiq::Worker.clear_all
  end

  teardown do
    ENV.delete("COACH_TESTERS")
    Sidekiq::Worker.clear_all
  end

  def assert_busy_json
    assert_response :too_many_requests
    assert_equal I18n.t("ux_i18n.ai_busy", locale: :ar), response.parsed_body["error"]
    assert_equal AiCircuit::OPEN_FOR.to_i.to_s, response.headers["Retry-After"]
  end

  def assert_busy_redirect(to)
    assert_redirected_to to
    assert_equal I18n.t("ux_i18n.ai_busy", locale: :ar), flash[:alert]
  end

  test "a CV generation is refused" do
    assert_no_difference -> { CvGeneration.count } do
      post cv_generations_path, params: { cv_generation: { resume_id: resumes(:complete_resume).id, job_description: "x" * 200 } }, as: :json
    end
    assert_busy_json
    assert_empty CvGeneratorJob.jobs
  end

  test "an HTML CV generation goes back with the message" do
    post cv_generations_path, params: { cv_generation: { job_description: "x" } }, headers: { "HTTP_REFERER" => new_cv_generation_url }
    assert_busy_redirect new_cv_generation_url
  end

  test "retry, regenerate and resume_draft are refused" do
    generation = create_test_cv_generation(@user, status: "failed", resume: resumes(:complete_resume))

    post retry_cv_generation_path(generation), headers: { "HTTP_REFERER" => cv_generation_url(generation) }
    assert_busy_redirect cv_generation_url(generation)
    assert_equal "failed", generation.reload.status

    generation.update_columns(status: "completed")
    post regenerate_cv_generation_path(generation), headers: { "HTTP_REFERER" => cv_generation_url(generation) }
    assert_busy_redirect cv_generation_url(generation)
    assert_nil generation.reload.metadata&.dig("regenerating_at")

    generation.update_columns(status: "draft", is_draft: true)
    post resume_draft_cv_generation_path(generation), as: :json
    assert_busy_json
    assert_equal "draft", generation.reload.status
  end

  test "a CV analysis is refused" do
    assert_no_difference -> { CvAnalysis.count } do
      post "/cv-analysis", params: { pdf_file: "x" }, as: :json
    end
    assert_busy_json
  end

  test "translations are refused" do
    assert_no_difference -> { AiTranslation.count } do
      post api_translate_professional_summary_path, params: { arabic_text: "نص" }, as: :json
      assert_busy_json
      post api_translate_job_descriptions_path, params: { arabic_text: "نص" }, as: :json
      assert_busy_json
    end
    assert_empty AiTranslationJob.jobs
  end

  test "CV and LinkedIn imports are refused" do
    assert_no_difference [ -> { CvImport.count }, -> { LinkedinImport.count } ] do
      post cv_import_path, params: { pdf_file: "x" }, as: :json
      assert_busy_json
      post "/linkedin-import", params: { pdf_file: "x" }, as: :json
      assert_busy_json
    end
  end

  test "a coach message and a coach import are refused; a plain chat still opens" do
    ENV["COACH_TESTERS"] = @user.email
    Coach.expects(:charge!).never
    chat = Coach::Chat.create!(user: @user, path: "scratch")

    assert_no_difference -> { chat.messages.count } do
      post message_coach_chat_url(chat), params: { content: "Hi" }, as: :json
    end
    assert_busy_json

    post coach_chats_path, params: { path: "import", resume_id: resumes(:complete_resume).id }, headers: { "HTTP_REFERER" => coach_root_url }
    assert_busy_redirect coach_root_url

    post coach_chats_path, params: { path: "scratch" }
    assert_redirected_to coach_chat_path(Coach::Chat.order(:id).last)
  end

  test "the coach checks its own queue" do
    ENV["COACH_TESTERS"] = @user.email
    AiCircuit.unstub(:busy?)
    AiCircuit.expects(:busy?).with(queue: "coach").returns(true)
    chat = Coach::Chat.create!(user: @user, path: "scratch")

    post message_coach_chat_url(chat), params: { content: "Hi" }, as: :json
    assert_busy_json
  end

  test "non-AI pages keep working" do
    get cv_generations_path
    assert_response :success
  end

  test "a full queue refuses with the same message while the breaker is closed" do
    AiCircuit.unstub(:busy?)
    AiCircuit.stubs(:open?).returns(false)
    AiCircuit.stubs(:queue_size).with("default").returns(AiCircuit.queue_limit + 1)

    post "/cv-analysis", params: { pdf_file: "x" }, as: :json
    assert_busy_json
  end
end
