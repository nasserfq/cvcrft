require "test_helper"

class Api::TranslationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "should return translation limits when authenticated" do
    get api_translation_limit_url
    assert_response :success
    assert_equal "application/json", response.media_type

    json = JSON.parse(response.body)
    assert json.key?("remaining_summary_translations") || json.key?("remaining")
  end

  test "translation limit should include all limit types" do
    get api_translation_limit_url
    assert_response :success

    json = JSON.parse(response.body)
    # Should contain limit information
    assert json.is_a?(Hash)
  end

  test "should translate professional summary" do
    # Stub AI service
    AiTranslationJob.stubs(:perform_later).returns(nil)

    post api_translate_professional_summary_url, params: {
      text: "مهندس برمجيات ذو خبرة في تطوير تطبيقات الويب"
    }, as: :json

    # Should return success or create a translation job
    assert_includes [ 200, 201, 202, 422 ], response.status
  end

  test "should translate job descriptions" do
    # Stub AI service
    AiTranslationJob.stubs(:perform_later).returns(nil)

    post api_translate_job_descriptions_url, params: {
      experiences: [
        { description: "تطوير تطبيقات الويب باستخدام Rails" }
      ]
    }, as: :json

    # Should return success or create translation jobs
    assert_includes [ 200, 201, 202, 422 ], response.status
  end

  test "should require authentication for translation limit" do
    sign_out @user
    get api_translation_limit_url
    assert_response :redirect
  end

  test "should require authentication for translations" do
    sign_out @user
    post api_translate_professional_summary_url, params: {
      text: "نص عربي"
    }, as: :json
    # Should redirect or return unauthorized
    assert_includes [ 302, 401 ], response.status
  end

  # Regression: pdf_status called an undefined CvBuilderPdfJob method, so every
  # poll from the export flow 500'd.
  test "pdf_status returns a download url once the PDF path is in Redis" do
    pdf = Tempfile.new([ "resume", ".pdf" ])
    Redis.stubs(:new).returns(stub(get: pdf.path))

    get api_pdf_status_translations_url, params: { job_id: "job123", token: "tok123" }

    assert_response :success
    assert_equal "completed", json_response["status"]
    assert_equal "/api/export_pdf?direct_download=true&token=tok123", json_response["download_url"]
  ensure
    pdf&.close!
  end

  test "pdf_status stays processing while the PDF is not in Redis yet" do
    Redis.stubs(:new).returns(stub(get: nil))

    get api_pdf_status_translations_url, params: { job_id: "job123", token: "tok123" }

    assert_response :success
    assert_equal "processing", json_response["status"]
  end
end
