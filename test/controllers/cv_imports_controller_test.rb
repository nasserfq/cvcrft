require "test_helper"
require "sidekiq/testing"

class CvImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # ============================================
  # SETUP
  # ============================================

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    sign_in @user
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  # ============================================
  # AUTHENTICATION TESTS
  # ============================================

  test "create requires authentication" do
    sign_out @user

    post cv_import_path, params: { pdf_file: mock_pdf_upload }

    # Should redirect to login page
    assert_response :redirect
  end

  test "status requires authentication" do
    sign_out @user
    import = create_cv_import_for_user(@user)

    get cv_import_status_path(import, format: :json)

    # JSON callers get 401, not a redirect to the HTML login page.
    assert_response :unauthorized
  end

  # ============================================
  # CREATE ACTION TESTS
  # ============================================

  test "create accepts PDF file and returns success" do
    stub_pdf_service_success

    assert_difference "CvImport.count", 1 do
      post cv_import_path, params: { pdf_file: mock_pdf_upload }
    end

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["id"].present?
    assert json_response["status_url"].present?
  end

  test "create enqueues CvImportJob" do
    stub_pdf_service_success

    assert_difference "CvImportJob.jobs.size", 1 do
      post cv_import_path, params: { pdf_file: mock_pdf_upload }
    end
  end

  test "create returns error when no file provided" do
    post cv_import_path, params: {}

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].present?
  end

  test "create returns error for corrupted PDF" do
    CvPdfImportService.any_instance.stubs(:parse).raises(
      CvPdfImportService::CorruptedFileError.new("الملف تالف")
    )

    post cv_import_path, params: { pdf_file: mock_pdf_upload }

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "corrupted_file", json_response["error_type"]
  end

  test "create returns error for Arabic content" do
    CvPdfImportService.any_instance.stubs(:parse).raises(
      CvPdfImportService::ArabicContentError.new("السيرة الذاتية تحتوي على نص عربي")
    )

    post cv_import_path, params: { pdf_file: mock_pdf_upload }

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "arabic_content", json_response["error_type"]
  end

  # ============================================
  # STATUS ACTION TESTS
  # ============================================

  test "status returns pending status" do
    import = create_cv_import_for_user(@user, status: "pending")

    get cv_import_status_path(import, format: :json)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "pending", json_response["status"]
    assert_not json_response["completed"]
    assert_not json_response["failed"]
  end

  test "status returns completed status" do
    import = create_cv_import_for_user(@user, status: "completed", parsed_data: { "complete_name" => "Test" })

    get cv_import_status_path(import, format: :json)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "completed", json_response["status"]
    assert json_response["completed"]
    assert_not json_response["failed"]
  end

  test "status returns failed status with error" do
    import = create_cv_import_for_user(@user, status: "failed", error_message: "Test error")

    get cv_import_status_path(import, format: :json)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "failed", json_response["status"]
    assert_not json_response["completed"]
    assert json_response["failed"]
    assert_equal "Test error", json_response["error_message"]
  end

  test "status returns 404 for non-existent import" do
    get cv_import_status_path(id: 999999, format: :json)

    assert_response :not_found
  end

  test "status returns 404 for other user's import" do
    other_user = users(:one)
    other_import = create_cv_import_for_user(other_user)

    get cv_import_status_path(other_import, format: :json)

    assert_response :not_found
  end

  # ============================================
  # SHOW ACTION TESTS
  # ============================================

  test "show returns parsed data for completed import" do
    import = create_cv_import_for_user(@user, status: "completed", parsed_data: { "complete_name" => "Test User" })

    get cv_import_show_path(import, format: :json)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["parsed_data"].present?
  end

  test "show returns error for pending import" do
    import = create_cv_import_for_user(@user, status: "pending")

    get cv_import_show_path(import, format: :json)

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].present?
  end

  test "show returns error for failed import" do
    import = create_cv_import_for_user(@user, status: "failed", error_message: "Failed")

    get cv_import_show_path(import, format: :json)

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert json_response["error"].present?
  end

  test "show returns 404 for other user's import" do
    other_user = users(:one)
    other_import = create_cv_import_for_user(other_user, status: "completed", parsed_data: { "complete_name" => "Other" })

    get cv_import_show_path(other_import, format: :json)

    assert_response :not_found
  end

  private

  def create_cv_import_for_user(user, attrs = {})
    CvImport.create!({
      user: user,
      original_filename: "test.pdf",
      extracted_text: "Test content",
      status: "pending"
    }.merge(attrs))
  end

  def mock_pdf_upload
    tempfile = Tempfile.new([ "test_cv", ".pdf" ])
    tempfile.write("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\nxref\n0 1\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R >>\nstartxref\n9\n%%EOF")
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "application/pdf", true, original_filename: "test_cv.pdf")
  end

  def stub_pdf_service_success
    CvPdfImportService.any_instance.stubs(:parse).returns({
      text: "John Doe\nSoftware Engineer",
      language: "en"
    })
  end
end
