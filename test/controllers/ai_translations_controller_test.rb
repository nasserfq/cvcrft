require "test_helper"

class AiTranslationsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get ai_translations_create_url
    assert_response :success
  end

  test "should get status" do
    get ai_translations_status_url
    assert_response :success
  end
end
