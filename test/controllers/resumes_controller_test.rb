require "test_helper"

class ResumesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    sign_in @user

    # Create a resume for testing
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @resume = Resume.create!(
      user: @user,
      complete_name: "Test User",
      email: "resume-test-#{SecureRandom.hex(4)}@example.com",
      phone_number: "123456789",
      is_draft: false
    )
  end

  test "should redirect to login when not authenticated" do
    sign_out @user
    get resumes_url
    assert_response :redirect
  end

  test "should get index when authenticated" do
    get resumes_url
    assert_response :success
  end

  test "should get new" do
    get new_resume_url
    assert_response :success
  end

  test "should create resume" do
    assert_difference("Resume.count") do
      post resumes_url, params: {
        resume: {
          complete_name: "New User",
          email: "new-user-#{SecureRandom.hex(4)}@example.com",
          phone_number: "987654321"
        }
      }
    end
    assert_redirected_to resume_url(Resume.last)
  end

  test "should show resume" do
    get resume_url(@resume)
    assert_response :success
  end

  test "should not show other user's resume" do
    other_resume = Resume.create!(
      user: @other_user,
      complete_name: "Other User",
      email: "other-resume-#{SecureRandom.hex(4)}@example.com",
      is_draft: false
    )
    get resume_url(other_resume)
    # Should redirect or return not found
    assert_includes [ 302, 404 ], response.status
  end

  test "should get edit" do
    get edit_resume_url(@resume)
    assert_response :success
  end

  test "should update resume" do
    patch resume_url(@resume), params: {
      resume: { complete_name: "Updated Name" }
    }
    assert_redirected_to resume_url(@resume)
    @resume.reload
    assert_equal "Updated Name", @resume.complete_name
  end

  test "should destroy resume" do
    assert_difference("Resume.count", -1) do
      delete resume_url(@resume)
    end
    assert_redirected_to resumes_url
  end
end
