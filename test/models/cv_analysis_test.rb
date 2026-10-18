require "test_helper"

class CvAnalysisTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    @user = users(:test_user)
    @cv_analysis = CvAnalysis.new(
      user: @user,
      original_filename: "test_cv.pdf",
      extracted_text: "Sample CV text content",
      language: "ar"
    )
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should be valid with all required attributes" do
    assert @cv_analysis.valid?
  end

  test "should require user" do
    @cv_analysis.user = nil
    assert_not @cv_analysis.valid?
    assert_includes @cv_analysis.errors[:user], "must exist"
  end

  test "should require original_filename" do
    @cv_analysis.original_filename = nil
    assert_not @cv_analysis.valid?
    assert_includes @cv_analysis.errors[:original_filename], "can't be blank"
  end

  test "should validate status inclusion" do
    @cv_analysis.status = "invalid_status"
    assert_not @cv_analysis.valid?
    assert_includes @cv_analysis.errors[:status], "is not included in the list"
  end

  test "should validate language inclusion" do
    @cv_analysis.language = "fr"
    assert_not @cv_analysis.valid?
    assert_includes @cv_analysis.errors[:language], "is not included in the list"
  end

  test "should allow blank language" do
    @cv_analysis.language = nil
    assert @cv_analysis.valid?
  end

  test "should accept valid languages" do
    %w[ar en].each do |lang|
      @cv_analysis.language = lang
      assert @cv_analysis.valid?, "#{lang} should be a valid language"
    end
  end

  test "should accept valid statuses" do
    %w[pending processing completed failed].each do |status|
      @cv_analysis.status = status
      assert @cv_analysis.valid?, "#{status} should be a valid status"
    end
  end

  # ============================================
  # DEFAULT VALUES TESTS
  # ============================================

  test "should set default status to pending" do
    analysis = CvAnalysis.new
    assert_equal "pending", analysis.status
  end

  test "should set default language to ar" do
    analysis = CvAnalysis.new
    assert_equal "ar", analysis.language
  end

  # ============================================
  # STATUS HELPER TESTS
  # ============================================

  test "pending? returns true when status is pending" do
    @cv_analysis.status = "pending"
    assert @cv_analysis.pending?
    assert_not @cv_analysis.processing?
    assert_not @cv_analysis.completed?
    assert_not @cv_analysis.failed?
  end

  test "processing? returns true when status is processing" do
    @cv_analysis.status = "processing"
    assert @cv_analysis.processing?
    assert_not @cv_analysis.pending?
    assert_not @cv_analysis.completed?
    assert_not @cv_analysis.failed?
  end

  test "completed? returns true when status is completed" do
    @cv_analysis.status = "completed"
    assert @cv_analysis.completed?
    assert_not @cv_analysis.pending?
    assert_not @cv_analysis.processing?
    assert_not @cv_analysis.failed?
  end

  test "failed? returns true when status is failed" do
    @cv_analysis.status = "failed"
    assert @cv_analysis.failed?
    assert_not @cv_analysis.pending?
    assert_not @cv_analysis.processing?
    assert_not @cv_analysis.completed?
  end

  # ============================================
  # STATE TRANSITION TESTS
  # ============================================

  test "mark_processing! updates status to processing" do
    @cv_analysis.save!
    @cv_analysis.mark_processing!
    assert_equal "processing", @cv_analysis.reload.status
  end

  test "progress defaults to 0" do
    assert_equal 0, CvAnalysis.new.progress
  end

  test "mark_processing! restarts progress" do
    @cv_analysis.progress = 80
    @cv_analysis.save!
    @cv_analysis.mark_processing!
    assert_equal 3, @cv_analysis.reload.progress
  end

  test "mark_completed! sets progress to 100" do
    @cv_analysis.save!
    @cv_analysis.mark_completed!({ "overall_score" => 70 })
    assert_equal 100, @cv_analysis.reload.progress
  end

  test "mark_completed! updates status and stores results" do
    @cv_analysis.save!
    results = {
      "overall_score" => 85,
      "section_scores" => { "ats_compatibility" => 80 },
      "strengths" => [ "Good formatting" ],
      "improvements" => [ "Add more keywords" ]
    }

    @cv_analysis.mark_completed!(results, "gpt-4.1-mini", 500)
    @cv_analysis.reload

    assert_equal "completed", @cv_analysis.status
    assert_equal results, @cv_analysis.analysis_results
    assert_equal "gpt-4.1-mini", @cv_analysis.ai_model
    assert_equal 500, @cv_analysis.tokens_used
  end

  test "mark_failed! updates status and stores error message" do
    @cv_analysis.save!
    @cv_analysis.mark_failed!("API connection failed")
    @cv_analysis.reload

    assert_equal "failed", @cv_analysis.status
    assert_equal "API connection failed", @cv_analysis.error_message
  end

  # ============================================
  # ANALYSIS RESULTS HELPER TESTS
  # ============================================

  test "overall_score returns score from analysis_results" do
    @cv_analysis.analysis_results = { "overall_score" => 75 }
    assert_equal 75, @cv_analysis.overall_score
  end

  test "overall_score returns 0 when no results" do
    @cv_analysis.analysis_results = nil
    assert_equal 0, @cv_analysis.overall_score
  end

  test "section_scores returns scores from analysis_results" do
    scores = { "ats_compatibility" => 80, "content_quality" => 75 }
    @cv_analysis.analysis_results = { "section_scores" => scores }
    assert_equal scores, @cv_analysis.section_scores
  end

  test "section_scores returns empty hash when no results" do
    @cv_analysis.analysis_results = nil
    assert_equal({}, @cv_analysis.section_scores)
  end

  test "strengths returns array from analysis_results" do
    strengths = [ "Good formatting", "Clear structure" ]
    @cv_analysis.analysis_results = { "strengths" => strengths }
    assert_equal strengths, @cv_analysis.strengths
  end

  test "strengths returns empty array when no results" do
    @cv_analysis.analysis_results = nil
    assert_equal [], @cv_analysis.strengths
  end

  test "improvements returns array from analysis_results" do
    improvements = [ "Add keywords", "Improve summary" ]
    @cv_analysis.analysis_results = { "improvements" => improvements }
    assert_equal improvements, @cv_analysis.improvements
  end

  test "improvements returns empty array when no results" do
    @cv_analysis.analysis_results = nil
    assert_equal [], @cv_analysis.improvements
  end

  test "ats_tips returns array from analysis_results" do
    tips = [ "Use standard fonts", "Avoid tables" ]
    @cv_analysis.analysis_results = { "ats_tips" => tips }
    assert_equal tips, @cv_analysis.ats_tips
  end

  test "ats_tips returns empty array when no results" do
    @cv_analysis.analysis_results = nil
    assert_equal [], @cv_analysis.ats_tips
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    # Clear existing analyses to avoid fixture interference
    CvAnalysis.delete_all

    old_analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "old.pdf",
      created_at: 2.days.ago
    )
    new_analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "new.pdf",
      created_at: 1.hour.ago
    )

    recent = CvAnalysis.recent.limit(2)
    assert_equal new_analysis, recent.first
  end

  test "pending scope returns only pending analyses" do
    @cv_analysis.save!
    completed = CvAnalysis.create!(user: @user, original_filename: "done.pdf", status: "completed")

    pending_analyses = CvAnalysis.pending.where(id: [ @cv_analysis.id, completed.id ])
    assert_includes pending_analyses, @cv_analysis
    assert_not_includes pending_analyses, completed
  end

  test "completed scope returns only completed analyses" do
    @cv_analysis.save!
    completed = CvAnalysis.create!(
      user: @user,
      original_filename: "done.pdf",
      status: "completed",
      analysis_results: { "overall_score" => 80 }
    )

    completed_analyses = CvAnalysis.completed
    assert_includes completed_analyses, completed
    assert_not_includes completed_analyses, @cv_analysis
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "belongs to user" do
    assert_respond_to @cv_analysis, :user
    assert_equal @user, @cv_analysis.user
  end
end
