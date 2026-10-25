require "test_helper"

class PdfTextTest < ActiveSupport::TestCase
  WEIRD = "Łukasz Żółć ✓ → 😀 ​ ‮".freeze

  setup do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    @resume = Resume.new(
      user: users(:one),
      complete_name: WEIRD,
      email: "pdf-text-#{SecureRandom.hex(4)}@example.com",
      phone_number: "123456789",
      city: WEIRD,
      country: "Polska",
      professional_summary_english: "Engineer #{WEIRD} with ten years of experience.",
      is_draft: false
    )
    @resume.save!(validate: false)
    @resume.skip_validations_for_pdf = true
    @resume.work_experiences.create!(job_title: "Lead #{WEIRD}", company: "Firma #{WEIRD}", start_date: "2020-01",
                                     responsibilities: [ "✓ Led a team → shipped v2 😀", WEIRD ])
    @resume.educations.create!(degree: "MSc #{WEIRD}", institution: "Politechnika #{WEIRD}", start_date: "2014-01", end_date: "2019-01")
    @resume.skills.create!(category: "technical", skill_names: [ "Ruby", WEIRD ])
    @resume.certifications.create!(name: "Cert #{WEIRD}", organization: "Org #{WEIRD}", date: "2021-01")
    @resume.languages.create!(language: "Polski #{WEIRD}", proficiency: "Native ✓")
    @resume.reload
  end

  test "sanitize maps to Windows-1252 and drops what Helvetica cannot draw" do
    assert_equal "Lukasz Zólc - -> ", PdfText.sanitize(WEIRD).squeeze(" ")
    assert_equal "“quoted” – café • ok", PdfText.sanitize("“quoted” – café • ok")
    assert_equal "Istanbul sirket", PdfText.sanitize("İstanbul şirket")
    assert_equal "", PdfText.sanitize("字‍﻿")
    PdfText.sanitize(WEIRD).encode("Windows-1252")
  end

  test "sanitize folds compatibility forms to plain text" do
    assert_equal "John Smith", PdfText.sanitize("Ｊｏｈｎ Ｓｍｉｔｈ")
    assert_equal "Led the office finance team", PdfText.sanitize("Led the oﬃce ﬁnance team")
    assert_equal "Phase IV 1 team", PdfText.sanitize("Phase Ⅳ ① team")
    assert_equal "Džuro Ljubo", PdfText.sanitize("ǅuro ǈubo")
    assert_equal "“quoted” – café • ok … ½ ™ X", PdfText.sanitize("“quoted” – café • ok … ½ ™ Ｘ")
  end

  test "every template renders a 200-character certification name and issuer" do
    words = ("Microsoft Certified Azure Solutions Architect Expert " * 5)[0, 200]
    @resume.certifications.destroy_all
    @resume.certifications.create!(name: words, organization: words, date: "2023-05")
    @resume.certifications.create!(name: "X" * 200, organization: "Y" * 200, date: "2023-05")
    @resume.reload

    AtsTemplatePdfService.template_catalog.each do |template|
      result = ResumePdfService.generate_pdf(@resume, template: template[:key])
      assert File.size(result[:path]).positive?, template[:key]
    end
  end

  test "every ATS template renders weird characters through ResumePdfService" do
    AtsTemplatePdfService.template_catalog.each do |template|
      result = ResumePdfService.generate_pdf(@resume, template: template[:key])
      assert File.size(result[:path]).positive?, template[:key]
    end
  end

  test "legacy generator renders weird characters" do
    data = { professional_summary: WEIRD, educations: [ { degree: WEIRD, institution: WEIRD, start_date: "2014", end_date: "2019" } ],
             skills: [ { category: WEIRD, details: WEIRD } ], certifications: [ { name: WEIRD, organization: WEIRD, date: "2021" } ],
             languages: [ { language: WEIRD, proficiency: WEIRD } ] }
    result = AtsPdfGenerator.generate_pdf(@resume, data, template: "classic_01")
    assert File.size(result[:path]).positive?
  end

  test "CV builder job path renders weird characters" do
    AtsTemplatePdfService.template_catalog.each do |template|
      result = CvBuilderPdfJob.new.send(:generate_pdf, @resume, "token", template[:key])
      assert File.size(result[:path]).positive?, template[:key]
    end
  end
end
