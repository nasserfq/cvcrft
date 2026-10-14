require "test_helper"

class ResumeBuilder::PublicApiTest < ActiveSupport::TestCase
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @draft = {
      "complete_name" => "Sara Ali",
      "email" => "sara@example.com",
      "phone_number" => "0500000000",
      "city" => "Riyadh",
      "country" => "Saudi Arabia",
      "professional_summary" => "Backend engineer.",
      "professional_summary_english" => "Backend engineer.",
      "work_experience" => [
        { "job_title" => "Engineer", "company" => "Acme", "start_date" => "2020-01", "end_date" => "2023-06",
          "is_current" => false, "responsibilities" => [ "Built APIs", "Led migrations" ] }
      ],
      "education" => [
        { "degree" => "BSc CS", "institution" => "KSU", "start_date" => "2015-09", "end_date" => "2019-06",
          "gpa" => "4.5", "is_current" => false }
      ],
      "skills" => [ { "category" => "Backend", "skill_names" => [ "Ruby", "Postgres" ] } ],
      "certifications" => [ { "name" => "AWS SAA", "organization" => "Amazon", "date" => "2022-03" } ],
      "languages" => [ { "language" => "Arabic", "proficiency" => "Native" } ]
    }
  end

  test "create_from_draft then read round-trips the draft" do
    resume = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft)

    assert_equal false, resume.is_draft
    assert_equal "coach", resume.source
    assert_equal @draft, ResumeBuilder::PublicApi.read(users(:one), resume.id)
  end

  test "read only finds the user's own resumes" do
    resume = ResumeBuilder::PublicApi.create_from_draft(users(:one), @draft)

    assert_raises(ActiveRecord::RecordNotFound) { ResumeBuilder::PublicApi.read(users(:two), resume.id) }
  end
end
