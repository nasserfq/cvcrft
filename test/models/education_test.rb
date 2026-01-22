require "test_helper"

class EducationTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert educations(:bachelors).valid?, "bachelors fixture should be valid"
    assert educations(:masters).valid?, "masters fixture should be valid"
    assert educations(:current_study).valid?, "current_study fixture should be valid"
    assert educations(:arabic_education).valid?, "arabic_education fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save education without degree" do
    education = Education.new(
      resume: resumes(:complete_resume),
      institution: "MIT",
      start_date: "2020-09"
    )
    assert_not education.valid?
    assert_includes education.errors[:degree], "can't be blank"
  end

  test "should not save education without institution" do
    education = Education.new(
      resume: resumes(:complete_resume),
      degree: "Bachelor of Science",
      start_date: "2020-09"
    )
    assert_not education.valid?
    assert_includes education.errors[:institution], "can't be blank"
  end

  test "should not save education without start_date" do
    education = Education.new(
      resume: resumes(:complete_resume),
      degree: "Bachelor of Science",
      institution: "MIT"
    )
    assert_not education.valid?
    assert_includes education.errors[:start_date], "can't be blank"
  end

  test "should save valid education" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    
    education = Education.new(
      resume: resumes(:complete_resume),
      degree: "Master of Computer Science",
      institution: "Stanford University",
      start_date: "2022-09",
      end_date: "2024-06",
      gpa: "3.9"
    )
    assert education.valid?
    assert education.save
  end

  test "should allow nil end_date for current education" do
    education = Education.new(
      resume: resumes(:complete_resume),
      degree: "PhD in AI",
      institution: "MIT",
      start_date: "2023-09",
      is_current: true
    )
    assert education.valid?
  end

  test "should allow nil gpa" do
    education = Education.new(
      resume: resumes(:complete_resume),
      degree: "Bachelor of Science",
      institution: "University",
      start_date: "2020-09",
      gpa: nil
    )
    assert education.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "education belongs to resume" do
    education = educations(:bachelors)
    assert_respond_to education, :resume
    assert_instance_of Resume, education.resume
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content" do
    education = educations(:arabic_education)
    assert_equal "بكالوريوس هندسة البرمجيات", education.degree
    assert_equal "جامعة الملك فهد للبترول والمعادن", education.institution
    assert education.valid?
  end
end
