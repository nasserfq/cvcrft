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

  # Prawn's cursor inside a stretchy bounding_box is always 0, so the old
  # "min of the two column cursors" jumped to the page bottom and pushed work
  # experience onto page 2.
  %w[two_column_corporate white_black_engineering minimalist_real_estate infographic_light].each do |key|
    test "#{key} keeps work experience on page one" do
      result = AtsTemplatePdfService.generate_pdf(@resume, sample_data, template: key)
      pages = PDF::Reader.new(result[:path]).pages

      assert_equal 1, pages.size
      assert_match(/WORK EXPERIENCE/, pages.first.text)
      assert_match(/Engineer/, pages.first.text)
    ensure
      File.delete(result[:path]) if result && File.exist?(result[:path])
    end
  end

  test "render_side_by_side continues below the taller column" do
    pdf = Prawn::Document.new
    start_y = pdf.y

    AtsTemplatePdfService.render_side_by_side(
      pdf, [ 0, 100 ], [ 120, 100 ],
      left: -> { pdf.move_down 50 },
      right: -> { pdf.move_down 200 }
    )

    assert_equal 1, pdf.page_number
    assert_in_delta start_y - 200, pdf.y, 0.01
  end

  test "render_side_by_side follows a column that spills onto the next page" do
    pdf = Prawn::Document.new
    pdf.move_down 600

    AtsTemplatePdfService.render_side_by_side(
      pdf, [ 0, 100 ], [ 120, 100 ],
      left: -> { 20.times { pdf.text "line" } },
      right: -> { pdf.move_down 10 }
    )

    line_height = pdf.height_of("line")
    assert_equal 2, pdf.page_count
    assert_equal 2, pdf.page_number
    # The spilled lines restart at the top margin, not at the column's page-1 offset.
    assert_operator pdf.y, :>, pdf.bounds.absolute_top - (20 * line_height)
  end

  test "parse_resume_date reads the date formats resumes carry" do
    service = AtsTemplatePdfService
    travel_to Date.new(2026, 10, 16) do
      assert_equal Date.new(2021, 3, 1), service.parse_resume_date("2021-03")
      assert_equal Date.new(2021, 3, 15), service.parse_resume_date("2021-03-15")
      assert_equal Date.new(2019, 1, 1), service.parse_resume_date("2019")
      assert_equal Date.new(2020, 7, 1), service.parse_resume_date("07/2020")
      assert_equal Date.new(2018, 5, 2), service.parse_resume_date(Date.new(2018, 5, 2))
      assert_equal Date.new(2026, 10, 16), service.parse_resume_date("Present")
      assert_nil service.parse_resume_date("")
      assert_nil service.parse_resume_date(nil)
      assert_nil service.parse_resume_date("2021-13")
      assert_nil service.parse_resume_date("someday")
    end
  end

  test "sort_experiences_newest_first orders mixed date formats newest first" do
    experiences = [
      WorkExperience.new(job_title: "Oldest", start_date: "2010"),
      WorkExperience.new(job_title: "Unknown", start_date: ""),
      WorkExperience.new(job_title: "Middle", start_date: "2015-06-01"),
      WorkExperience.new(job_title: "Current", start_date: "2012-01", is_current: true),
      WorkExperience.new(job_title: "Recent", start_date: "2020-02")
    ]

    sorted = AtsTemplatePdfService.sort_experiences_newest_first(experiences)

    assert_equal %w[Current Recent Middle Oldest Unknown], sorted.map(&:job_title)
  end

  private
    def sample_data
      {
        professional_summary: "Experienced professional with a strong background.",
        educations: [ { degree: "BSc", institution: "University", start_date: "2018-01", end_date: "2022-01" } ],
        skills: [ { category: "Technical", details: "Ruby" } ],
        languages: [ { language: "English", proficiency: "Fluent" } ],
        certifications: []
      }
    end
end
