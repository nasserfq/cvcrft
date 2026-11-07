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

  def perform_jobs(body, job_id: SecureRandom.hex(6), options: {})
    AiModel.stubs(:complete).returns(Reply.new(body.to_json, Tokens.new(10, 20)))
    AiTranslationJob.new.perform(
      "[مدير - شركة]\nإدارة الفريق", @user.id, @resume&.id,
      { "job_descriptions" => true, "job_id" => job_id, "max_tokens" => 2000 }.merge(options)
    )
    AiTranslation.where("metadata->>'job_id' = ?", job_id).sole
  end

  def with_paid_translation(kind)
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:jobs_translations_count, UserUsageLimits::BASE_JOBS_TRANSLATIONS)
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
    job_id = SecureRandom.hex(6)
    assert_equal :credit, Billing::UsageGate.allow!(@user, kind, key: job_id)
    yield job_id
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "translated job descriptions complete the translation" do
    jobs = [ { "job_title" => "مدير", "company" => "شركة", "responsibilities_english" => [ "Led the team" ] } ]

    translation = perform_jobs({ jobs: jobs, skills_extracted: [] })

    assert_equal "completed", translation.status
    assert_equal jobs, JSON.parse(translation.english_text)["jobs"]
  end

  test "a reply with no translated jobs fails and gives the credit back" do
    with_paid_translation(:jobs_translation) do |job_id|
      balance = Billing::Credits.balance(@user)

      translation = perform_jobs({ jobs: [], skills_extracted: [] }, job_id: job_id,
                                 options: { "overage_kind" => "jobs_translation" })

      assert_equal "failed", translation.status
      assert_equal "ai_empty_reply", translation.metadata["error_code"]
      assert_equal balance + Billing::UsageGate.cost(:jobs_translation), Billing::Credits.balance(@user)
    end
  end

  test "jobs with only blank duties count as no translation" do
    translation = perform_jobs({ jobs: [ { "job_title" => "مدير", "responsibilities_english" => [ " " ] } ] })

    assert_equal "failed", translation.status
  end

  test "a retry of a completed translation does not call the AI again" do
    job_id = SecureRandom.hex(6)
    body = { english_text: "Project manager.", skills_extracted: [] }.to_json
    AiModel.stubs(:complete).returns(Reply.new(body, Tokens.new(10, 20)))
    assert_equal "completed", perform(job_id).status

    AiModel.expects(:complete).never
    assert_equal "completed", perform(job_id).status
  end

  test "the translation is not completed when saving the resume fails" do
    @resume.update_column(:professional_summary_english, "Old summary.")
    body = { english_text: "Project manager and Scrum Master.", skills_extracted: [] }.to_json
    AiModel.stubs(:complete).returns(Reply.new(body, Tokens.new(10, 20)))
    job_id = SecureRandom.hex(6)

    AiTranslationJob.new.perform(
      "مدير مشروع و سكرم ماستر", @user.id, @resume.id,
      { "professional_summary" => true, "job_id" => job_id, "work_experience_id" => -1 }
    )

    translation = AiTranslation.where("metadata->>'job_id' = ?", job_id).sole
    assert_equal "failed", translation.status
    assert_equal "Old summary.", @resume.reload.professional_summary_english
  end

  test "exhausted retries fail the translation and give the credit back" do
    with_paid_translation(:summary_translation) do |job_id|
      balance = Billing::Credits.balance(@user)
      options = { "job_id" => job_id, "overage_kind" => "summary_translation" }
      translation = @user.ai_translations.create!(arabic_text: "مدير مشروع", ai_model: "test", status: "processing", metadata: options)

      AiTranslationJob.sidekiq_retries_exhausted_block.call(
        { "args" => [ "مدير مشروع", @user.id, nil, options ] }, RubyLLM::RateLimitError.new("Too many requests")
      )

      assert_equal "failed", translation.reload.status
      assert_equal "ai_unavailable", translation.metadata["error_code"]
      assert_equal balance + Billing::UsageGate.cost(:summary_translation), Billing::Credits.balance(@user)
    end
  end

  test "exhausted retries leave a completed translation alone" do
    options = { "job_id" => SecureRandom.hex(6) }
    translation = @user.ai_translations.create!(arabic_text: "مدير مشروع", ai_model: "test", status: "completed",
                                                english_text: "Project manager.", metadata: options)

    AiTranslationJob.sidekiq_retries_exhausted_block.call(
      { "args" => [ "مدير مشروع", @user.id, nil, options ] }, RuntimeError.new("late")
    )

    assert_equal "completed", translation.reload.status
    assert_equal "Project manager.", translation.english_text
  end
end
