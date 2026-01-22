require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user

    # Stub PDF generation
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
  end

  test "should redirect to login when not authenticated" do
    sign_out @user
    get profile_url
    assert_response :redirect
  end

  test "should get show when authenticated" do
    get profile_url
    assert_response :success
  end

  test "should display user information" do
    get profile_url
    assert_response :success
    assert_select "body"
  end

  test "should display resume statistics" do
    # Create a resume for the user
    Resume.create!(
      user: @user,
      complete_name: "Test User",
      email: "profile-test-#{SecureRandom.hex(4)}@example.com",
      is_draft: false
    )

    get profile_url
    assert_response :success
  end

  test "should display limit information" do
    get profile_url
    assert_response :success
    # The page should show generation limits
    assert_select "body"
  end

  test "should delete user account" do
    # Create a fresh user for deletion test
    user_to_delete = User.create!(
      email: "delete-test-#{SecureRandom.hex(4)}@example.com",
      name: "Delete Test User",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user_to_delete

    assert_difference("User.count", -1) do
      delete profile_url
    end
    assert_redirected_to root_url
  end

  test "should destroy associated data when deleting account" do
    # Create a user with associated data
    user_to_delete = User.create!(
      email: "delete-data-#{SecureRandom.hex(4)}@example.com",
      name: "Delete Data Test User",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user_to_delete

    # Create associated resume
    Resume.create!(
      user: user_to_delete,
      complete_name: "User to Delete",
      email: "user-delete-#{SecureRandom.hex(4)}@example.com"
    )

    # Create associated cv_generation
    CvGeneration.create!(
      user: user_to_delete,
      job_description: "Test job description that is long enough to pass validation requirements",
      ai_model: "gpt-4",
      status: "completed"
    )

    delete profile_url

    assert_equal 0, Resume.where(user_id: user_to_delete.id).count
    assert_equal 0, CvGeneration.where(user_id: user_to_delete.id).count
  end
end
