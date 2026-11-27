require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::ProfileAnswersTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  PA = JobApplications::ProfileAnswers
  YES_NO = %w[Yes No].freeze

  setup do
    @profile = create_profile(users(:one), expected_salary_sar: 20_000)
    @contact = { "complete_name" => "Sara Ali Hassan", "email" => "sara@example.com", "city" => "Riyadh", "country" => "Saudi Arabia" }
  end

  def q(label, type: "text", options: [], section: "main", required: true)
    { "id" => "q1", "label" => label, "type" => type, "options" => options, "required" => required, "section" => section }
  end

  def match(label, profile: @profile, **opts)
    PA.match(q(label, **opts), profile:, contact: @contact)
  end

  test "splits the resume name and fills email, city, phone and LinkedIn" do
    assert_equal "Sara", match("First Name")
    assert_equal "Ali Hassan", match("Last Name")
    assert_equal "Sara Ali Hassan", match("Full name")
    assert_equal "sara@example.com", match("Email", type: "email")
    assert_equal "Riyadh", match("City")
    assert_equal "+966 500000000", match("Phone", type: "tel")
    assert_equal "https://www.linkedin.com/in/sara", match("LinkedIn Profile", type: "url")
  end

  test "a resume upload gets the CV, other files and EEO questions never reach the AI" do
    assert_equal "cv_pdf", match("Resume/CV", type: "file")
    assert_equal :sensitive, match("Portfolio", type: "file")
    assert_nil match("Cover Letter", type: "file")
    assert_equal :sensitive, match("Which best describes you?", type: "select", options: %w[A B], section: "eeo")
    assert_equal :sensitive, match("Gender", type: "select", options: %w[Female Male])
  end

  test "Saudi national yes or no follows the profile" do
    assert_equal "Yes", match("Are you a Saudi national?", type: "select", options: YES_NO)
    other = create_profile(users(:two), visa_status: "iqama_transferable", nationality: "Egyptian")

    assert_equal "No", match("Are you a Saudi national?", profile: other, type: "radio", options: YES_NO)
    assert_equal "Egyptian", match("Nationality", profile: other)
  end

  test "a KSA visa question is answered, a UAE one waits for the user" do
    iqama = create_profile(users(:two), visa_status: "iqama_not_transferable")

    assert_equal "No", match("Will you require visa sponsorship to work in KSA?", type: "select", options: YES_NO)
    assert_equal "Yes", match("Will you require visa sponsorship to work in KSA?", profile: iqama, type: "select", options: YES_NO)
    assert_equal "Yes", match("Are you legally authorized to work in Saudi Arabia?", type: "select", options: YES_NO)
    assert_equal "No", match("Is your Iqama transferable?", profile: iqama, type: "select", options: YES_NO)
    assert_equal "Saudi citizen", match("What is your current visa status?")
    assert_equal :sensitive, match("Are you authorized to work in the UAE?", type: "select", options: YES_NO)
    assert_equal :sensitive, match("Do you need a visa to work in the United Kingdom?", type: "select", options: YES_NO)
  end

  test "salary is monthly, times 12 when yearly, and missing in another currency or without one" do
    assert_equal "20000", match("Expected monthly salary (SAR)", type: "number")
    assert_equal "240000", match("What are your annual salary expectations?")
    assert_equal :sensitive, match("Expected salary (USD)")
    assert_equal :sensitive, match("Expected hourly rate salary")
    assert_equal :sensitive, match("Expected salary", profile: create_profile(users(:two), expected_salary_sar: nil))
  end

  test "notice period as text or as the matching option" do
    assert_equal "1 month", match("What is your notice period?")
    assert_equal "1 month", match("Notice period", type: "select", options: [ "Immediately", "1 month", "2 months" ])
    assert_equal :sensitive, match("Notice period", type: "select", options: [ "Less than 30 days", "More" ])
  end

  test "Arabic labels" do
    assert_equal "Sara", match("الاسم الأول")
    assert_equal "Ali Hassan", match("اسم العائلة")
    assert_equal "+966 500000000", match("رقم الجوال")
    assert_equal "Saudi", match("الجنسية")
    assert_equal "نعم", match("هل أنت مواطن سعودي؟", type: "radio", options: %w[نعم لا])
    assert_equal "لا", match("هل تحتاج إلى كفالة؟", type: "radio", options: %w[نعم لا])
    assert_equal "20000", match("الراتب الشهري المتوقع")
    assert_equal "Riyadh", match("مكان الإقامة")
    assert_equal :sensitive, match("الجنس", type: "radio", options: %w[ذكر أنثى])
    assert_equal :sensitive, match("أوافق على الشروط والأحكام", type: "checkbox", options: [ "نعم" ])
  end

  test "unknown questions are left for the AI" do
    assert_nil match("Why do you want to work here?", type: "textarea")
    assert_not PA.topic?(q("Why do you want to work here?"))
    assert PA.topic?(q("Expected salary"))
  end
end
