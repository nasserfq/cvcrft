require "test_helper"

class WorkExperiencesControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get work_experiences_create_url
    assert_response :success
  end

  test "should get update" do
    get work_experiences_update_url
    assert_response :success
  end

  test "should get destroy" do
    get work_experiences_destroy_url
    assert_response :success
  end
end
