require "test_helper"
require "sidekiq/testing"

class LinkedinImportJobTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    @linkedin_import = LinkedinImport.create!(
      user: @user,
      original_filename: "test_linkedin.pdf",
      extracted_text: "John Doe\nSoftware Engineer at Tech Company\nExperience: 5 years"
    )
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  # ============================================
  # JOB ENQUEUEING TESTS
  # ============================================

  test "job is enqueued to Sidekiq" do
    assert_equal 0, LinkedinImportJob.jobs.size

    LinkedinImportJob.perform_async(@linkedin_import.id)

    assert_equal 1, LinkedinImportJob.jobs.size
  end

  test "job is enqueued with correct arguments" do
    LinkedinImportJob.perform_async(@linkedin_import.id)

    job = LinkedinImportJob.jobs.first
    assert_equal [ @linkedin_import.id ], job["args"]
  end

  # ============================================
  # JOB BEHAVIOR TESTS (inline mode)
  # ============================================

  test "job marks import as processing then completed on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      LinkedinImportJob.perform_async(@linkedin_import.id)
      @linkedin_import.reload

      assert_equal "completed", @linkedin_import.status
      assert @linkedin_import.parsed_data.present?
    end
  end

  test "job handles missing linkedin_import by raising RecordNotFound" do
    Sidekiq::Testing.inline! do
      assert_raises(ActiveRecord::RecordNotFound) do
        LinkedinImportJob.new.perform(-1)
      end
    end
  end

  test "job marks import as failed on API error" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_failure

      assert_raises(StandardError) do
        LinkedinImportJob.new.perform(@linkedin_import.id)
      end

      @linkedin_import.reload
      assert_equal "failed", @linkedin_import.status
      assert @linkedin_import.error_message.present?
    end
  end

  test "job stores parsed data on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      LinkedinImportJob.perform_async(@linkedin_import.id)
      @linkedin_import.reload

      assert @linkedin_import.parsed_data["complete_name"].present?
      assert @linkedin_import.parsed_data["professional_summary"].present?
      assert @linkedin_import.parsed_data["work_experiences"].is_a?(Array)
    end
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  private

  def stub_azure_openai_success
    mock_response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "complete_name" => "John Doe",
              "email" => "john@example.com",
              "phone_number" => "+1234567890",
              "city" => "San Francisco",
              "country" => "USA",
              "professional_summary" => "Experienced software engineer with 5 years of experience",
              "work_experiences" => [
                {
                  "job_title" => "Senior Software Engineer",
                  "company" => "Tech Company",
                  "start_date" => "2020-01",
                  "end_date" => "",
                  "is_current" => true,
                  "responsibilities" => [
                    "Led development team",
                    "Built scalable systems"
                  ]
                }
              ],
              "educations" => [
                {
                  "degree" => "Bachelor of Science in Computer Science",
                  "institution" => "Stanford University",
                  "end_date" => "2018"
                }
              ],
              "skills" => [
                {
                  "category" => "Technical",
                  "items" => [ "Ruby", "Python", "JavaScript" ]
                }
              ],
              "certifications" => []
            }.to_json
          }
        }
      ],
      "usage" => { "total_tokens" => 800 }
    }

    mock_http_response = stub(code: "200", body: mock_response.to_json)
    Net::HTTP.any_instance.stubs(:request).returns(mock_http_response)
  end

  def stub_azure_openai_failure
    Net::HTTP.any_instance.stubs(:request).raises(StandardError.new("API Error"))
  end
end
