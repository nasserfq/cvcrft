require "test_helper"

class ResumeDraftSyncTest < ActiveSupport::TestCase
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @user = users(:one)
    @resume = Resume.create!(
      user: @user,
      complete_name: "Old Name",
      email: "old@example.com",
      phone_number: "111",
      city: "Old City",
      country: "Old Country",
      professional_summary: "Old summary",
      professional_summary_english: "Old summary",
      is_draft: false
    )
    @resume.work_experiences.create!(
      job_title: "Old Role",
      company: "Old Co",
      start_date: "2020-01",
      responsibilities: [ "Old task" ]
    )
  end

  test "syncs draft_data onto resume and associations for preview" do
    draft_data = {
      "complete_name" => "Nasser Alqahtani",
      "email" => "non1993@protonmail.com",
      "phone_number" => "+966500000000",
      "city" => "Riyadh",
      "country" => "Saudi Arabia",
      "professional_summary" => "Updated summary",
      "professional_summary_english" => "Updated summary",
      "work_experience" => [
        {
          "job_title" => "Product Manager",
          "company" => "New Co",
          "start_date" => "2023-01",
          "end_date" => "",
          "is_current" => true,
          "responsibilities" => [ "Shipped features" ]
        }
      ].to_json,
      "education" => [
        {
          "degree" => "BSc CS",
          "institution" => "Test University",
          "start_date" => "2014-01",
          "end_date" => "2018-01"
        }
      ].to_json,
      "skills" => [
        { "category" => "technical", "skill_names" => [ "Ruby", "Rails" ] }
      ].to_json,
      "certifications" => [
        { "name" => "AWS", "organization" => "Amazon", "date" => "2024-01" }
      ].to_json,
      "languages" => [
        { "language" => "English", "proficiency" => "Fluent" }
      ].to_json
    }

    ResumeDraftSync.sync!(@resume, draft_data)
    @resume.reload

    assert_equal "Nasser Alqahtani", @resume.complete_name
    assert_equal "non1993@protonmail.com", @resume.email
    assert_equal "Updated summary", @resume.professional_summary_english
    assert_equal 1, @resume.work_experiences.count
    assert_equal "Product Manager", @resume.work_experiences.first.job_title
    assert_equal "New Co", @resume.work_experiences.first.company
    assert_equal 1, @resume.educations.count
    assert_equal 1, @resume.skills.count
    assert_equal 1, @resume.certifications.count
    assert_equal 1, @resume.languages.count
  end
end
