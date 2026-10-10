require "test_helper"
require "sidekiq/testing"

class CvImportJobTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    @cv_import = CvImport.create!(
      user: @user,
      original_filename: "test_cv.pdf",
      extracted_text: sample_cv_text
    )
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  # ============================================
  # JOB ENQUEUEING TESTS
  # ============================================

  test "job is enqueued to Sidekiq" do
    assert_equal 0, CvImportJob.jobs.size

    CvImportJob.perform_async(@cv_import.id)

    assert_equal 1, CvImportJob.jobs.size
  end

  test "job is enqueued with correct arguments" do
    CvImportJob.perform_async(@cv_import.id)

    job = CvImportJob.jobs.first
    assert_equal [ @cv_import.id ], job["args"]
  end

  # ============================================
  # JOB BEHAVIOR TESTS (inline mode)
  # ============================================

  test "job marks import as processing then completed on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      assert_equal "completed", @cv_import.status
      assert @cv_import.parsed_data.present?
    end
  end

  test "job handles missing cv_import by raising RecordNotFound" do
    Sidekiq::Testing.inline! do
      assert_raises(ActiveRecord::RecordNotFound) do
        CvImportJob.perform_async(999999)
      end
    end
  end

  test "job marks import as failed on API error" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_failure

      assert_raises(RuntimeError) do
        CvImportJob.perform_async(@cv_import.id)
      end

      @cv_import.reload
      assert_equal "failed", @cv_import.status
      assert @cv_import.error_message.present?
    end
  end

  test "job parses complete_name from response" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      assert_equal "John Doe", @cv_import.parsed_data["complete_name"]
    end
  end

  test "job parses email from response" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      assert_equal "john.doe@example.com", @cv_import.parsed_data["email"]
    end
  end

  test "job parses work_experiences from response" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      work_experiences = @cv_import.parsed_data["work_experiences"]
      assert work_experiences.is_a?(Array)
      assert_equal 2, work_experiences.size
      assert_equal "Software Engineer", work_experiences.first["job_title"]
    end
  end

  test "job parses educations from response" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      educations = @cv_import.parsed_data["educations"]
      assert educations.is_a?(Array)
      assert_equal 1, educations.size
      assert_equal "Bachelor of Computer Science", educations.first["degree"]
    end
  end

  test "job parses skills from response" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      skills = @cv_import.parsed_data["skills"]
      assert skills.is_a?(Array)
      assert skills.any? { |s| s["category"] == "Technical Skills" }
    end
  end

  test "job clears error_message on successful completion" do
    @cv_import.update!(error_message: "Previous error")

    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      CvImportJob.perform_async(@cv_import.id)
      @cv_import.reload

      assert_nil @cv_import.error_message
    end
  end

  private

  def sample_cv_text
    <<~TEXT
      John Doe
      john.doe@example.com | +1234567890 | New York, USA

      PROFESSIONAL SUMMARY
      Experienced Software Engineer with 5+ years in web development.

      EDUCATION
      Bachelor of Computer Science
      MIT University

      WORK EXPERIENCE
      Software Engineer
      Tech Company
      2020-01 - Present
      • Developed web applications using Ruby on Rails
      • Led team of 5 developers

      Junior Developer
      Startup Inc
      2018-01 - 2019-12
      • Built RESTful APIs
      • Wrote unit tests

      SKILLS
      Technical Skills: Ruby, Python, JavaScript
      Soft Skills: Leadership, Communication

      CERTIFICATIONS
      AWS Certified Developer - 2023
    TEXT
  end

  def stub_azure_openai_success
    mock_response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "complete_name" => "John Doe",
              "email" => "john.doe@example.com",
              "phone_number" => "+1234567890",
              "city" => "New York",
              "country" => "USA",
              "professional_summary" => "Experienced Software Engineer with 5+ years in web development.",
              "work_experiences" => [
                {
                  "job_title" => "Software Engineer",
                  "company" => "Tech Company",
                  "start_date" => "2020-01",
                  "end_date" => "",
                  "is_current" => true,
                  "responsibilities" => [
                    "Developed web applications using Ruby on Rails",
                    "Led team of 5 developers"
                  ]
                },
                {
                  "job_title" => "Junior Developer",
                  "company" => "Startup Inc",
                  "start_date" => "2018-01",
                  "end_date" => "2019-12",
                  "is_current" => false,
                  "responsibilities" => [
                    "Built RESTful APIs",
                    "Wrote unit tests"
                  ]
                }
              ],
              "educations" => [
                {
                  "degree" => "Bachelor of Computer Science",
                  "institution" => "MIT University",
                  "start_date" => "",
                  "end_date" => "",
                  "gpa" => "",
                  "is_current" => false
                }
              ],
              "skills" => [
                {
                  "category" => "Technical Skills",
                  "skill_names" => [ "Ruby", "Python", "JavaScript" ]
                },
                {
                  "category" => "Soft Skills",
                  "skill_names" => [ "Leadership", "Communication" ]
                }
              ],
              "certifications" => [
                {
                  "name" => "AWS Certified Developer",
                  "organization" => "AWS",
                  "date" => "2023"
                }
              ],
              "languages" => []
            }.to_json
          }
        }
      ],
      "usage" => { "total_tokens" => 800 }
    }

    stub_ai_response(mock_response.dig("choices", 0, "message", "content"))
  end

  def stub_azure_openai_failure
    stub_ai_failure
  end
end
