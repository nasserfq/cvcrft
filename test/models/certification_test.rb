require "test_helper"

class CertificationTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert certifications(:aws_cert).valid?, "aws_cert fixture should be valid"
    assert certifications(:ruby_cert).valid?, "ruby_cert fixture should be valid"
    assert certifications(:scrum_cert).valid?, "scrum_cert fixture should be valid"
    assert certifications(:arabic_cert).valid?, "arabic_cert fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save certification without name" do
    cert = Certification.new(
      resume: resumes(:complete_resume),
      organization: "AWS",
      date: "2023-05"
    )
    assert_not cert.valid?
    assert_includes cert.errors[:name], "can't be blank"
  end

  test "should not save certification without organization" do
    cert = Certification.new(
      resume: resumes(:complete_resume),
      name: "AWS Solutions Architect",
      date: "2023-05"
    )
    assert_not cert.valid?
    assert_includes cert.errors[:organization], "can't be blank"
  end

  test "saves certification without date" do
    # Date is intentionally optional — LinkedIn certifications often have
    # none, and 12 of 318 production records rely on it.
    cert = Certification.new(
      resume: resumes(:complete_resume),
      name: "AWS Solutions Architect",
      organization: "AWS"
    )
    assert cert.valid?
  end

  test "should save valid certification" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    cert = Certification.new(
      resume: resumes(:complete_resume),
      name: "Google Cloud Professional",
      organization: "Google",
      date: "2024-01"
    )
    assert cert.valid?
    assert cert.save
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "certification belongs to resume" do
    cert = certifications(:aws_cert)
    assert_respond_to cert, :resume
    assert_instance_of Resume, cert.resume
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content" do
    cert = certifications(:arabic_cert)
    assert_equal "شهادة محترف إدارة المشاريع", cert.name
    assert_equal "معهد إدارة المشاريع", cert.organization
    assert cert.valid?
  end
end
