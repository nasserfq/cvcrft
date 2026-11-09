require "test_helper"

# A job that starts while the AI breaker is open never reaches the provider,
# stays processing for a later retry (never failed early), charges nothing and
# refunds nothing; its retry waits for the breaker to close.
class AiCircuitJobsTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @user = users(:user_with_resumes)
    @cache = ActiveSupport::Cache::MemoryStore.new
    AiCircuit.stubs(:cache).returns(@cache)
    AiCircuit::FAILURE_LIMIT.times do
      AiCircuit.call { raise RubyLLM::ServiceUnavailableError, "down" }
    rescue RubyLLM::ServiceUnavailableError
      nil
    end
    assert AiCircuit.open?
    RubyLLM.expects(:chat).never
    Billing::UsageGate.expects(:allow!).never
    Billing::UsageGate.expects(:refund!).never
  end

  def assert_waits_for_breaker(job_class)
    delay = job_class.sidekiq_retry_in_block.call(1, AiCircuit::OpenError.new, {})
    assert_operator delay, :>=, AiCircuit::OPEN_FOR.to_i
  end

  test "CV generation stays processing and retries after the breaker closes" do
    generation = create_test_cv_generation(@user, resume: resumes(:complete_resume))

    assert_raises(AiCircuit::OpenError) do
      CvGeneratorJob.new.perform(generation.job_description, @user.id, generation.resume_id, { "cv_generation_id" => generation.id })
    end
    assert_equal "processing", generation.reload.status
    assert_waits_for_breaker(CvGeneratorJob)
    assert_nil CvGeneratorJob.sidekiq_retry_in_block.call(1, RuntimeError.new, {})
  end

  test "translation stays processing and is not failed" do
    job_id = SecureRandom.hex(6)
    assert_raises(AiCircuit::OpenError) do
      AiTranslationJob.new.perform("مدير مشروع", @user.id, nil, { "professional_summary" => true, "job_id" => job_id })
    end

    translation = AiTranslation.where("metadata->>'job_id' = ?", job_id).sole
    assert_equal "processing", translation.status
    assert_equal "ai_unavailable", translation.metadata["error_code"]
    assert_waits_for_breaker(AiTranslationJob)
    assert_equal 10, AiTranslationJob.sidekiq_retry_in_block.call(1, RuntimeError.new, {})
  end

  test "CV analysis stays processing" do
    analysis = CvAnalysis.create!(user: @user, original_filename: "cv.pdf", extracted_text: "John Doe\nEngineer", language: "en")

    assert_raises(AiCircuit::OpenError) { CvAnalysisJob.new.perform(analysis.id) }
    assert_equal "processing", analysis.reload.status
    assert_waits_for_breaker(CvAnalysisJob)
  end

  test "CV and LinkedIn imports stay processing" do
    cv_import = CvImport.create!(user: @user, original_filename: "cv.pdf", extracted_text: "John Doe")
    linkedin_import = LinkedinImport.create!(user: @user, original_filename: "in.pdf", extracted_text: "John Doe")

    assert_raises(AiCircuit::OpenError) { CvImportJob.new.perform(cv_import.id, "key") }
    assert_raises(AiCircuit::OpenError) { LinkedinImportJob.new.perform(linkedin_import.id, "key") }
    assert_equal %w[processing processing], [ cv_import.reload.status, linkedin_import.reload.status ]
    [ CvImportJob, LinkedinImportJob ].each { |job| assert_waits_for_breaker(job) }
    assert_equal 20, CvImportJob.sidekiq_retry_in_block.call(1, RuntimeError.new, {})
  end

  test "a coach turn ends with a refund and no Sentry report, without calling the model" do
    Billing::UsageGate.unstub(:refund!)
    chat = Coach::Chat.create!(user: users(:one), path: "scratch")
    turn = chat.messages.create!(role: "user", content: "Hi")
    Billing::Credits.spend!(chat.user, 1, reason: "coach_message", key: Coach.charge_key(turn))
    Coach::Agent.any_instance.expects(:reply).never
    Sentry.expects(:capture_exception).never

    Coach::TurnJob.perform_now(chat.id, turn.id)

    assert turn.reload.turn_ended?
    assert CreditLedgerEntry.exists?(reason: "refund", idempotency_key: "refund:#{Coach.charge_key(turn)}")
    assert_broadcast_on("coach:#{chat.id}", type: "error")
  end
end
