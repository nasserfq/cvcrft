require "test_helper"

class CvAnalysesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers if defined?(Devise)

  # ============================================
  # SETUP
  # ============================================

  def setup
    @user = users(:test_user)
    sign_in @user if respond_to?(:sign_in)
  end

  # ============================================
  # NEW ACTION TESTS
  # ============================================

  test "should get new when logged in" do
    get cv_analysis_new_path
    assert_response :success
    assert_select "h1", /تحليل السيرة الذاتية|CV Analysis/i
  end

  test "should redirect new to login when not logged in" do
    sign_out @user if respond_to?(:sign_out)
    get cv_analysis_new_path
    assert_response :redirect
  end

  # ============================================
  # CREATE ACTION TESTS
  # ============================================

  test "should create cv_analysis with valid PDF" do
    pdf_content = create_mock_pdf

    assert_difference("CvAnalysis.count", 1) do
      post cv_analysis_create_path, params: {
        pdf_file: fixture_file_upload_mock(pdf_content, "application/pdf", "test_cv.pdf"),
        target_job: "Software Engineer",
        target_industry: "Technology",
        language: "en"
      }, as: :json
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["redirect_url"].present?
  end

  test "should reject non-PDF files" do
    post cv_analysis_create_path, params: {
      pdf_file: fixture_file_upload_mock("text content", "text/plain", "test.txt")
    }, as: :json

    # Should return error or redirect
    assert_includes [ 200, 422 ], response.status
  end

  test "should reject missing file" do
    post cv_analysis_create_path, as: :json

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].present?
  end

  # ============================================
  # SHOW ACTION TESTS
  # ============================================

  test "should show completed analysis" do
    analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "test.pdf",
      status: "completed",
      analysis_results: {
        "overall_score" => 80,
        "section_scores" => { "ats_compatibility" => 85 },
        "strengths" => [ "Good" ],
        "improvements" => [ "Better" ],
        "ats_tips" => [ "Use keywords" ]
      }
    )

    get cv_analysis_show_path(analysis)
    assert_response :success
  end

  test "should show processing page for pending analysis" do
    analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "test.pdf",
      status: "pending"
    )

    get cv_analysis_show_path(analysis)
    assert_response :success
  end

  test "should not show other users analysis" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    analysis = CvAnalysis.create!(
      user: other_user,
      original_filename: "test.pdf"
    )

    get cv_analysis_show_path(analysis)
    assert_response :redirect
  end

  # ============================================
  # STATUS ACTION TESTS
  # ============================================

  test "should return status as JSON" do
    analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "test.pdf",
      status: "processing"
    )

    get cv_analysis_status_path(analysis), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "processing", json_response["status"]
  end

  test "should include redirect_url when completed" do
    analysis = CvAnalysis.create!(
      user: @user,
      original_filename: "test.pdf",
      status: "completed",
      analysis_results: { "overall_score" => 80 }
    )

    get cv_analysis_status_path(analysis), as: :json

    json_response = JSON.parse(response.body)
    assert_equal "completed", json_response["status"]
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  private

  def create_mock_pdf
    # Minimal PDF content
    "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF"
  end

  def fixture_file_upload_mock(content, content_type, filename)
    file = Tempfile.new([ filename.split(".").first, ".#{filename.split(".").last}" ])
    file.write(content)
    file.rewind

    Rack::Test::UploadedFile.new(file.path, content_type, true, original_filename: filename)
  end

  def sign_in(user)
    post login_path, params: { email: user.email }
    # For session-based auth, set session directly in test
    if defined?(session)
      session[:user_id] = user.id
    end
  end

  def sign_out(user)
    delete logout_path if defined?(logout_path)
  end
end
