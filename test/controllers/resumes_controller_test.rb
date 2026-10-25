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

  test "new reuses existing empty starter draft" do
    starter = Resume.create!(
      user: @user,
      complete_name: "starter",
      email: @user.email,
      is_draft: true,
      draft_data: { "current_step" => 1 }
    )

    get new_resume_url

    assert_redirected_to edit_resume_path(starter, step: 1)
    assert_equal 1, @user.resumes.drafts.count
  end

  test "save_draft with new reuses existing empty starter draft" do
    starter = Resume.create!(
      user: @user,
      complete_name: "starter",
      email: @user.email,
      is_draft: true,
      draft_data: { "current_step" => 1 }
    )

    assert_no_difference("Resume.count") do
      post save_draft_resume_path("new"), params: {
        complete_name: "starter",
        email: @user.email,
        current_step: 1,
        education: "[]",
        work_experience: "[]",
        skills: "[]",
        certifications: "[]",
        languages: "[]"
      }, as: :json
    end

    assert_response :success
    assert_equal starter.id, JSON.parse(response.body)["resume_id"]
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

  test "generate_pdf passes selected ATS template" do
    ResumeDraftSync.expects(:sync!).never
    ResumePdfService.expects(:generate_pdf).with(@resume, has_entry(template: "minimalist_real_estate")).returns("%PDF-1.4")

    get generate_pdf_resume_url(@resume), params: { template: "minimalist_real_estate" }

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "generate_pdf preview syncs draft data before rendering" do
    @resume.update!(
      draft_data: {
        "complete_name" => "Preview Name",
        "email" => @resume.email,
        "work_experience" => [].to_json
      }
    )

    ResumeDraftSync.expects(:sync!).with(@resume).returns(@resume)
    ResumePdfService.expects(:generate_pdf).with(@resume, has_entry(template: "harvard_classic")).returns("%PDF-1.4")

    get generate_pdf_resume_url(@resume), params: { preview: "true", template: "harvard_classic" }

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "generate_pdf preview answers 422 with the field error for a future work start date" do
    @resume.update!(
      draft_data: {
        "complete_name" => "Preview Name",
        "email" => @resume.email,
        "work_experience" => [ { "job_title" => "Engineer", "company" => "Acme", "start_date" => "2099-01" } ].to_json
      }
    )

    get generate_pdf_resume_url(@resume), params: { preview: "true" }

    assert_response :unprocessable_entity
    assert_equal "Start date cannot be in the future", response.body
  end

  test "generate_pdf preview answers 422 for an end date before the start date" do
    @resume.update!(
      draft_data: {
        "email" => @resume.email,
        "work_experience" => [ { "job_title" => "Engineer", "company" => "Acme", "start_date" => "2022-01", "end_date" => "2019-03" } ].to_json
      }
    )

    get generate_pdf_resume_url(@resume, format: :json), params: { preview: "true" }

    assert_response :unprocessable_entity
    assert_equal [ "End date must be after start date" ], response.parsed_body["errors"]
  end

  test "generate_pdf falls back to default template for invalid key" do
    # The default is the first entry in AtsStyleCatalog, i.e. original_classic.
    ResumePdfService.expects(:generate_pdf).with(@resume, has_entry(template: "original_classic")).returns("%PDF-1.4")

    get generate_pdf_resume_url(@resume), params: { template: "not_valid" }

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end
end
