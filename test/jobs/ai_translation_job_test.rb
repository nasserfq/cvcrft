require "test_helper"

class AiTranslationJobTest < ActiveSupport::TestCase
  Reply = Struct.new(:content, :tokens)
  Tokens = Struct.new(:input, :output)

  setup do
    @user = users(:test_user)
    @resume = @user.resumes.first
  end

  def perform(job_id = SecureRandom.hex(6))
    AiTranslationJob.new.perform(
      "مدير مشروع و سكرم ماستر", @user.id, @resume&.id,
      { "professional_summary" => true, "job_id" => job_id, "max_tokens" => 500 }
    )
    AiTranslation.where("metadata->>'job_id' = ?", job_id).order(:created_at).last
  end

  test "a good reply completes the translation" do
    body = { english_text: "Project manager and Scrum Master.", skills_extracted: [], translation_notes: "" }.to_json
    AiModel.stubs(:complete).returns(Reply.new(body, Tokens.new(10, 20)))

    translation = perform
    assert_equal "completed", translation.status
    assert_equal "Project manager and Scrum Master.", translation.english_text
  end

  test "an invalid AWS key fails at once with ai_key_invalid" do
    AiModel.stubs(:complete).raises(RubyLLM::ForbiddenError.new("The security token included in the request is invalid."))

    translation = perform
    assert_equal "failed", translation.status
    assert_equal "ai_key_invalid", translation.metadata["error_code"]
  end

  test "no access to the model fails with ai_no_model_access" do
    AiModel.stubs(:complete).raises(RubyLLM::ForbiddenError.new("You don't have access to the model with the specified model ID."))

    assert_equal "ai_no_model_access", perform.metadata["error_code"]
  end

  test "a throttled request stays processing and is retried on the same record" do
    job_id = SecureRandom.hex(6)
    AiModel.stubs(:complete).raises(RubyLLM::RateLimitError.new("Too many requests"))
    assert_raises(RubyLLM::RateLimitError) { perform(job_id) }
    assert_equal "processing", AiTranslation.where("metadata->>'job_id' = ?", job_id).sole.status

    body = { english_text: "Project manager.", skills_extracted: [] }.to_json
    AiModel.stubs(:complete).returns(Reply.new(body, Tokens.new(10, 20)))
    translation = perform(job_id)
    assert_equal "completed", translation.status
    assert_equal 1, AiTranslation.where("metadata->>'job_id' = ?", job_id).count
  end

  test "a rejected API key fails with ai_key_invalid" do
    AiModel.stubs(:complete).raises(RubyLLM::UnauthorizedError.new("bad key"))
    assert_equal "ai_key_invalid", perform.metadata["error_code"]
  end

  test "a short summary still completes and is saved on the resume" do
    body = { english_text: "Project manager and Scrum Master.", skills_extracted: [] }.to_json
    AiModel.stubs(:complete).returns(Reply.new(body, Tokens.new(10, 20)))

    assert_equal "completed", perform.status
    assert_equal "Project manager and Scrum Master.", @resume.reload.professional_summary_english
  end
end
