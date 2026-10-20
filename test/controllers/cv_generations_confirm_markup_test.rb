require "test_helper"

# Turbo is not loaded, so data-turbo-confirm does nothing: the CV generations
# list must confirm through the confirm-delete Stimulus dialog.
class CvGenerationsConfirmMarkupTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    resume = @user.resumes.create!(complete_name: "Saved CV", is_draft: false,
                                   email: "confirm-gen-#{SecureRandom.hex(4)}@example.com")
    @user.cv_generations.create!(resume: resume, status: "completed", job_description: "Rails engineer role",
                                 ai_model: "test", metadata: { source: "job_description" })
    @user.cv_generations.create!(resume: resume, status: "draft", job_description: "Draft engineer role",
                                 ai_model: "test", metadata: { source: "job_description" })
  end

  test "delete and resume-draft forms go through the confirm dialog" do
    get cv_generations_url
    assert_response :success

    assert_select "[data-controller~='confirm-delete']", 1
    assert_select "[data-turbo-confirm]", 0
    assert_select "dialog[data-confirm-delete-target='dialog']", 1

    delete_forms = css_select("form").select do |f|
      f.at_css("input[name='_method'][value='delete']") && !f["action"].to_s.include?("logout")
    end
    resume_forms = css_select("form").select { |f| f["action"].to_s.include?("resume_draft") }
    assert_operator delete_forms.size, :>=, 2
    assert_operator resume_forms.size, :>=, 1

    (delete_forms + resume_forms).each do |form|
      assert_equal "submit->confirm-delete#intercept", form["data-action"]
      assert form["data-confirm-delete-title-param"].present?
      assert form["data-confirm-delete-body-param"].present?
    end
  end

  test "cv generation page and resumes list confirm through the dialog" do
    draft = @user.cv_generations.find_by(status: "draft")
    [ cv_generation_url(draft), resumes_url ].each do |url|
      get url
      assert_response :success
      assert_select "[data-turbo-confirm]", 0
      assert_select "[data-controller~='confirm-delete']", 1
      assert_select "dialog[data-confirm-delete-target='dialog']", 1
      css_select("form[data-action]").each do |form|
        next unless form["data-action"].include?("confirm-delete#intercept")

        assert form["data-confirm-delete-body-param"].present?
      end
    end
  end
end
