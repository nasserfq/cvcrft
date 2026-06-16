require "test_helper"

class AtsTemplatePdfServiceTest < ActiveSupport::TestCase
  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @user = users(:one)
    @resume = Resume.create!(
      user: @user,
      complete_name: "Template Test",
      email: "template-test@example.com",
      phone_number: "123456789",
      city: "Riyadh",
      country: "Saudi Arabia",
      professional_summary_english: "Experienced professional with a strong background.",
      is_draft: false
    )
    @resume.work_experiences.create!(
      job_title: "Engineer",
      company: "Acme",
      start_date: "2022-01",
      responsibilities: [ "Built features" ]
    )
    @resume.educations.create!(
      degree: "BSc",
      institution: "University",
      start_date: "2018-01",
      end_date: "2022-01"
    )
    @resume.skills.create!(category: "technical", skill_names: [ "Ruby" ])
    @resume.languages.create!(language: "English", proficiency: "Fluent")
  end

  test "generates white_black_engineering template without error" do
    result = ResumePdfService.generate_pdf(@resume, template: "white_black_engineering")

    assert result.is_a?(Hash)
    assert File.exist?(result[:path])
    assert_operator File.size(result[:path]), :>, 0
  end
end
