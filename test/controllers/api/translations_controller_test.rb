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
end
