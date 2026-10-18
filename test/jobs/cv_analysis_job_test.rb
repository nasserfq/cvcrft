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
      AiModel.expects(:complete).with(has_entry(max_tokens: 8000)).returns(reply)

      CvAnalysisJob.perform_async(@cv_analysis.id)
    end
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
