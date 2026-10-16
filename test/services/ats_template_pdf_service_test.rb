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

  # Written out literally from the `case` that generate_pdf used before the
  # layouts moved onto the preset classes. Each key must reach the same
  # renderer with the same options.
  EXPECTED_DISPATCH = {
    "harvard_classic" => [ :render_single_column_layout, {} ],
    "white_black_engineering" => [
      :render_two_column_layout,
      {
        left_width_ratio: 0.28,
        sidebar_title: "TECH PROFILE",
        sidebar_sections: [ :contact, :skills, :languages ],
        main_sections: [ :summary, :education, :work_experience, :certifications ]
      }
    ],
    "simple_clean_gray" => [ :render_profile_band_layout, { band_color: "6B7280" } ],
    "minimalist_real_estate" => [
      :render_two_column_layout,
      {
        left_width_ratio: 0.24,
        sidebar_title: "PROFILE SNAPSHOT",
        sidebar_sections: [ :contact, :languages ],
        main_sections: [ :summary, :education, :skills, :work_experience, :certifications ]
      }
    ],
    "two_column_corporate" => [
      :render_two_column_layout,
      {
        left_width_ratio: 0.32,
        sidebar_title: "CORPORATE PROFILE",
        sidebar_sections: [ :contact, :languages, :skills ],
        main_sections: [ :summary, :education, :work_experience, :certifications ]
      }
    ],
    "blue_minimal_professional" => [ :render_profile_band_layout, { band_color: "1E3A8A" } ],
    "black_white_corporate" => [ :render_corporate_layout, {} ],
    "infographic_light" => [ :render_infographic_layout, {} ],
    "clean_single_column" => [ :render_clean_layout, {} ],
    "business_admin_modern" => [ :render_business_admin_layout, {} ]
  }.freeze

  EXPECTED_DISPATCH.each do |key, (renderer, options)|
    test "#{key} dispatches to #{renderer} with its options" do
      style_config = AtsStylePresets::AtsStyleCatalog.catalog.find { |s| s[:key] == key }[:config]
      AtsPdfGenerator.expects(:generate_pdf).never
      AtsTemplatePdfService.expects(renderer)
        .with(instance_of(Prawn::Document), @resume, anything, style_config, **options)
        .once

      AtsTemplatePdfService.generate_pdf(@resume, {}, template: key)
    end
  end

  test "original_classic renders through the legacy generator" do
    AtsPdfGenerator.expects(:generate_pdf)
      .with(@resume, anything, template: "classic_01")
      .returns({ path: "x.pdf", filename: "x.pdf" })

    assert_equal({ path: "x.pdf", filename: "x.pdf" },
      AtsTemplatePdfService.generate_pdf(@resume, {}, template: "original_classic"))
  end

  test "an unknown key falls back to the default style" do
    AtsPdfGenerator.expects(:generate_pdf).with(@resume, anything, template: "classic_01").returns({})

    AtsTemplatePdfService.generate_pdf(@resume, {}, template: "no_such_template")
  end
end
