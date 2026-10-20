require "test_helper"

# Peak-End: a finished analysis ends on improving the CV, not on starting over.
class CvAnalysisNextStepTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:test_user)
    sign_in @user
  end

  test "coach is the primary next step when coach is on" do
    Coach.stubs(:enabled_for?).returns(true)
    get cv_analysis_show_path(completed_analysis("en"))

    assert_response :success
    assert_select "a.sr-primary[data-cta=improve-with-coach][href=?]", coach_root_path, text: /Improve with Coach/
    assert_select "a.glass-soft[data-cta=edit-in-builder][href=?]", resumes_path, text: /Edit in builder/
    assert_select "a[data-cta=analyze-another][href=?]", cv_analysis_path, text: /Analyze another CV/
  end

  test "builder is the primary next step when coach is off" do
    Coach.stubs(:enabled_for?).returns(false)
    get cv_analysis_show_path(completed_analysis("en"))

    assert_select "a[data-cta=improve-with-coach]", count: 0
    assert_select "a.sr-primary[data-cta=edit-in-builder][href=?]", resumes_path
    assert_select "a[data-cta=analyze-another]"
  end

  test "next step labels follow the analysis language" do
    Coach.stubs(:enabled_for?).returns(true)
    get cv_analysis_show_path(completed_analysis("ar"))

    assert_select "a[data-cta=improve-with-coach]", text: /#{I18n.t("ux_next.cv_analysis.improve_with_coach", locale: :ar)}/
    assert_select "a[data-cta=edit-in-builder]", text: /#{I18n.t("ux_next.cv_analysis.edit_in_builder", locale: :ar)}/
  end

  private

  def completed_analysis(language)
    CvAnalysis.create!(user: @user, original_filename: "cv.pdf", status: "completed", language: language,
                       analysis_results: { "overall_score" => 80, "strengths" => [], "improvements" => [] })
  end
end
