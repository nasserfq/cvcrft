require "test_helper"
require "sidekiq/testing"

class CvAnalysisJobTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    @cv_analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "test_cv.pdf",
      extracted_text: "John Doe\nSoftware Engineer\n5 years experience in Ruby on Rails",
      language: "en"
    )
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  # ============================================
  # JOB ENQUEUEING TESTS
  # ============================================

  test "job is enqueued to Sidekiq" do
    assert_equal 0, CvAnalysisJob.jobs.size

    CvAnalysisJob.perform_async(@cv_analysis.id)

    assert_equal 1, CvAnalysisJob.jobs.size
  end

  test "job is enqueued with correct arguments" do
    CvAnalysisJob.perform_async(@cv_analysis.id)

    job = CvAnalysisJob.jobs.first
    assert_equal [ @cv_analysis.id ], job["args"]
  end

  test "job is enqueued to default queue" do
    CvAnalysisJob.perform_async(@cv_analysis.id)

    job = CvAnalysisJob.jobs.first
    assert_equal "default", job["queue"]
  end

  # ============================================
  # JOB BEHAVIOR TESTS (inline mode)
  # ============================================

  test "job marks analysis as completed on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvAnalysisJob.perform_async(@cv_analysis.id)
      @cv_analysis.reload

      assert_equal "completed", @cv_analysis.status
      assert @cv_analysis.analysis_results.present?
    end
  end

  test "job parses a reply wrapped in a json code fence" do
    Sidekiq::Testing.inline! do
      stub_ai_response("```json\n" + { overall_score: 82, strengths: [ "Clear" ] }.to_json + "\n```")

      CvAnalysisJob.perform_async(@cv_analysis.id)
      @cv_analysis.reload

      assert_equal "completed", @cv_analysis.status
      assert_equal 82, @cv_analysis.analysis_results["overall_score"]
    end
  end

  # 4000 cut long analyses off mid-JSON (Sentry RUBY-RAILS-4).
  test "job leaves room for a long analysis" do
    Sidekiq::Testing.inline! do
      reply = Struct.new(:content, :tokens).new({ overall_score: 70 }.to_json, nil)
      AiModel.expects(:complete).with(has_entries(max_tokens: 8000, temperature: 0.3)).twice.returns(reply)

      CvAnalysisJob.perform_async(@cv_analysis.id)
    end
  end

  test "job makes two streamed calls and merges them into one report" do
    stub_parts(scores: SCORES_PART, details: DETAILS_PART)

    CvAnalysisJob.new.perform(@cv_analysis.id)
    @cv_analysis.reload

    assert_equal "completed", @cv_analysis.status
    results = @cv_analysis.analysis_results
    assert_equal %w[overall_score section_scores strengths improvements ats_tips detailed_feedback keyword_analysis].sort,
                 results.keys.sort
    assert_equal 75, results["overall_score"]
    assert_equal 80, results.dig("section_scores", "ats_compatibility", "score")
    assert_equal [ "Use standard section headers" ], results["ats_tips"]
    assert_equal "Clear and focused.", results.dig("detailed_feedback", "professional_summary")
    assert_equal [ "Ruby", "Rails" ], results.dig("keyword_analysis", "found_keywords")
    assert_equal 800 + 600, @cv_analysis.tokens_used
    assert_equal AiModel.default, @cv_analysis.ai_model
  end

  test "job only asks for ATS tips in the scores call" do
    prompts = []
    reply = Struct.new(:content, :tokens).new({ overall_score: 70 }.to_json, nil)
    AiModel.stubs(:complete).with { |**opts| prompts << opts[:system] }.returns(reply)

    CvAnalysisJob.new.perform(@cv_analysis.id)

    assert_equal 2, prompts.size
    scores_prompt = prompts.find { |p| p.include?("\"ats_tips\"") }
    details_prompt = prompts.find { |p| p.include?("\"keyword_analysis\"") }
    assert scores_prompt, "one call asks for the scores and ATS tips"
    assert details_prompt, "one call asks for detailed feedback and keywords"
    assert_not_same scores_prompt, details_prompt
    assert_includes scores_prompt, "NEVER contradict the ats_compatibility feedback"
    prompts.each { |p| assert_includes p, "Respond ONLY in English" }
  end

  test "job reaches 100 percent progress when it completes" do
    stub_parts(scores: SCORES_PART, details: DETAILS_PART)

    CvAnalysisJob.new.perform(@cv_analysis.id)

    assert_equal 100, @cv_analysis.reload.progress
  end

  test "job marks analysis as failed when one part fails" do
    stub_parts(scores: SCORES_PART, details: RuntimeError.new("Bedrock timeout"))

    error = assert_raises(RuntimeError) { CvAnalysisJob.new.perform(@cv_analysis.id) }
    assert_equal "Bedrock timeout", error.message

    @cv_analysis.reload
    assert_equal "failed", @cv_analysis.status
    assert_equal "Bedrock timeout", @cv_analysis.error_message
    assert_operator @cv_analysis.progress, :<, 100
  end

  test "job marks analysis as failed when one part is not JSON" do
    stub_parts(scores: SCORES_PART, details: "Sorry, I cannot help with that.")

    assert_raises(RuntimeError) { CvAnalysisJob.new.perform(@cv_analysis.id) }

    @cv_analysis.reload
    assert_equal "failed", @cv_analysis.status
    assert_match(/Failed to parse AI response as JSON/, @cv_analysis.error_message)
  end

  # ============================================
  # PROGRESS TRACKER TESTS
  # ============================================

  test "progress tracker turns streamed characters into a throttled, rising percentage" do
    @cv_analysis.mark_processing!
    times = [ 10.0, 10.1, 11.0, 12.0 ]
    tracker = CvAnalysisJob::ProgressTracker.new(@cv_analysis, { scores: 100, details: 100 }, clock: -> { times.shift })

    tracker.add(:scores, 50)    # 25 % of the total => 5 + 90 * 0.25
    assert_equal 28, @cv_analysis.reload.progress

    tracker.add(:details, 100)  # within 0.75 s of the last write: skipped
    assert_equal 28, @cv_analysis.reload.progress

    tracker.add(:details, 0)    # 75 % now counted
    assert_equal 73, @cv_analysis.reload.progress

    tracker.add(:scores, 5000)  # overlong part counts as full; capped at 95
    assert_equal 95, @cv_analysis.reload.progress
  end

  test "progress tracker never lowers progress" do
    @cv_analysis.update!(status: "processing", progress: 50)
    tracker = CvAnalysisJob::ProgressTracker.new(@cv_analysis, { scores: 100, details: 100 })

    tracker.add(:scores, 10)

    assert_equal 50, @cv_analysis.reload.progress
  end

  test "job handles missing cv_analysis by raising RecordNotFound" do
    Sidekiq::Testing.inline! do
      assert_raises(ActiveRecord::RecordNotFound) do
        CvAnalysisJob.new.perform(-1)
      end
    end
  end

  test "job marks analysis as failed on API error" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_failure

      assert_raises(StandardError) do
        CvAnalysisJob.new.perform(@cv_analysis.id)
      end

      @cv_analysis.reload
      assert_equal "failed", @cv_analysis.status
      assert @cv_analysis.error_message.present?
    end
  end

  test "job stores analysis results on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvAnalysisJob.perform_async(@cv_analysis.id)
      @cv_analysis.reload

      assert_equal 75, @cv_analysis.overall_score
      assert @cv_analysis.section_scores.present?
      assert @cv_analysis.strengths.present?
      assert @cv_analysis.improvements.present?
    end
  end

  test "job records AI model and tokens used" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvAnalysisJob.perform_async(@cv_analysis.id)
      @cv_analysis.reload

      assert @cv_analysis.ai_model.present?
      assert @cv_analysis.tokens_used.present?
    end
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  private

  SCORES_PART = {
    "overall_score" => 75,
    "section_scores" => {
      "ats_compatibility" => { "score" => 80, "feedback" => "Standard headings." }
    },
    "strengths" => [ "Clear structure" ],
    "improvements" => [ { "issue" => "Few numbers", "suggestion" => "Quantify results", "priority" => "high" } ],
    "ats_tips" => [ "Use standard section headers" ]
  }.freeze

  DETAILS_PART = {
    "detailed_feedback" => { "professional_summary" => "Clear and focused." },
    "keyword_analysis" => { "found_keywords" => [ "Ruby", "Rails" ], "missing_keywords" => [ "AWS" ] }
  }.freeze

  Chunk = Struct.new(:content)
  Reply = Struct.new(:content, :tokens)
  Usage = Struct.new(:input, :output)

  # Stubs both parallel calls. Each part streams its reply in three chunks to
  # the job's block, then returns the whole message, as RubyLLM does. A part
  # given an exception raises it instead.
  def stub_parts(scores:, details:)
    { scores => /"ats_tips"/, details => /"keyword_analysis"/ }.each do |outcome, marker|
      expectation = AiModel.stubs(:complete).with { |**opts| opts[:system].match?(marker) }
      if outcome.is_a?(Exception)
        expectation.raises(outcome)
      else
        text = outcome.is_a?(String) ? outcome : outcome.to_json
        tokens = outcome.equal?(scores) ? Usage.new(500, 300) : Usage.new(400, 200)
        chunks = text.scan(/.{1,#{(text.length / 3.0).ceil}}/m).map { |piece| [ Chunk.new(piece) ] }
        expectation.multiple_yields(*chunks).returns(Reply.new(text, tokens))
      end
    end
  end

  def stub_azure_openai_success
    mock_response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "overall_score" => 75,
              "section_scores" => {
                "ats_compatibility" => 80,
                "content_quality" => 70,
                "formatting" => 75,
                "keyword_optimization" => 70,
                "impact_statements" => 80
              },
              "strengths" => [ "Clear structure", "Good experience section" ],
              "improvements" => [ "Add more keywords", "Quantify achievements" ],
              "ats_tips" => [ "Use standard section headers" ],
              "detailed_feedback" => {
                "ats_compatibility" => "Good format for ATS",
                "content_quality" => "Content is relevant",
                "formatting" => "Well organized",
                "keyword_optimization" => "Could use more industry keywords",
                "impact_statements" => "Good use of action verbs"
              }
            }.to_json
          }
        }
      ],
      "usage" => { "total_tokens" => 500 }
    }

    stub_ai_response(mock_response.dig("choices", 0, "message", "content"))
  end

  def stub_azure_openai_failure
    stub_ai_failure
  end
end
