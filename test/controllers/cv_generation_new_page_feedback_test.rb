require "test_helper"

# The standalone CV generation page reports problems in a glass toast and the
# inline error box, never with window.alert(), and its plain-DOM fallback uses
# real HTML class attributes.
class CvGenerationNewPageFeedbackTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    @user.resumes.create!(complete_name: "Test User", is_draft: false,
                   email: "cvgen-feedback-#{SecureRandom.hex(4)}@example.com")
  end

  test "page uses the toast helper instead of alert and has no className in innerHTML" do
    get new_cv_generation_url
    assert_response :success

    body = response.body
    assert_no_match(/(?<![\w.])alert\(/, body)
    assert_includes body, "window.cvToast = function"
    assert_select "#cv-toast-region", 1
    assert_no_match(/innerHTML = '<div className=/, body)
    assert_includes body, "setUpgradeUrl(window.cvSafeUrl(errorPayload && errorPayload.upgrade_url))"
  end
end
