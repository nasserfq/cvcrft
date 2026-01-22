require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert languages(:arabic).valid?, "arabic fixture should be valid"
    assert languages(:english).valid?, "english fixture should be valid"
    assert languages(:french).valid?, "french fixture should be valid"
    assert languages(:arabic_lang).valid?, "arabic_lang fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save language without language name" do
    lang = Language.new(
      resume: resumes(:complete_resume),
      proficiency: "Native"
    )
    assert_not lang.valid?
    assert_includes lang.errors[:language], "can't be blank"
  end

  test "should not save language without proficiency" do
    lang = Language.new(
      resume: resumes(:complete_resume),
      language: "Arabic"
    )
    assert_not lang.valid?
    assert_includes lang.errors[:proficiency], "can't be blank"
  end

  test "should save valid language" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    
    lang = Language.new(
      resume: resumes(:complete_resume),
      language: "German",
      proficiency: "Beginner"
    )
    assert lang.valid?
    assert lang.save
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "language belongs to resume" do
    lang = languages(:english)
    assert_respond_to lang, :resume
    assert_instance_of Resume, lang.resume
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content" do
    lang = languages(:arabic_lang)
    assert_equal "العربية", lang.language
    assert_equal "اللغة الأم", lang.proficiency
    assert lang.valid?
  end
end
