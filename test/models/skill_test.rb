require "test_helper"

class SkillTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert skills(:technical_skills).valid?, "technical_skills fixture should be valid"
    assert skills(:soft_skills).valid?, "soft_skills fixture should be valid"
    assert skills(:language_skills).valid?, "language_skills fixture should be valid"
    assert skills(:beginner_skill).valid?, "beginner_skill fixture should be valid"
    assert skills(:arabic_skill).valid?, "arabic_skill fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save skill without category" do
    skill = Skill.new(
      resume: resumes(:complete_resume),
      skill_names: ["Ruby", "Rails"]
    )
    assert_not skill.valid?
    assert_includes skill.errors[:category], "can't be blank"
  end

  test "should not save skill without skill_names" do
    skill = Skill.new(
      resume: resumes(:complete_resume),
      category: "technical"
    )
    assert_not skill.valid?
    assert_includes skill.errors[:skill_names], "can't be blank"
  end

  test "should validate level inclusion" do
    valid_levels = %w[beginner intermediate advanced expert]
    
    valid_levels.each do |level|
      skill = Skill.new(
        resume: resumes(:complete_resume),
        category: "technical",
        skill_names: ["Ruby"],
        level: level
      )
      assert skill.valid?, "#{level} should be a valid level"
    end
  end

  test "should reject invalid level" do
    skill = Skill.new(
      resume: resumes(:complete_resume),
      category: "technical",
      skill_names: ["Ruby"],
      level: "invalid_level"
    )
    assert_not skill.valid?
    assert skill.errors[:level].any?
  end

  test "should allow blank level" do
    skill = Skill.new(
      resume: resumes(:complete_resume),
      category: "technical",
      skill_names: ["Ruby"],
      level: nil
    )
    assert skill.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "skill belongs to resume" do
    skill = skills(:technical_skills)
    assert_respond_to skill, :resume
    assert_instance_of Resume, skill.resume
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "by_category scope filters by category" do
    technical = Skill.by_category("technical")
    technical.each do |skill|
      assert_equal "technical", skill.category
    end
  end

  test "by_level scope filters by level" do
    experts = Skill.by_level("expert")
    experts.each do |skill|
      assert_equal "expert", skill.level
    end
  end

  test "technical scope returns only technical skills" do
    technical = Skill.technical
    technical.each do |skill|
      assert_equal "technical", skill.category
    end
  end

  test "soft scope returns only soft skills" do
    soft = Skill.soft
    soft.each do |skill|
      assert_equal "soft", skill.category
    end
  end

  test "languages scope returns only language skills" do
    languages = Skill.languages
    languages.each do |skill|
      assert_equal "language", skill.category
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "level_score returns correct score for each level" do
    assert_equal 1, Skill.new(level: "beginner").level_score
    assert_equal 2, Skill.new(level: "intermediate").level_score
    assert_equal 3, Skill.new(level: "advanced").level_score
    assert_equal 4, Skill.new(level: "expert").level_score
    assert_equal 0, Skill.new(level: nil).level_score
  end

  test "display_name joins skill_names with comma" do
    skill = skills(:technical_skills)
    display = skill.display_name
    assert display.include?(",") || skill.skill_names.length == 1
  end

  test "display_name falls back to name and level when skill_names is blank" do
    skill = Skill.new(name: "Ruby", level: "expert", skill_names: nil)
    assert_equal "Ruby (expert)", skill.display_name
  end

  test "technical? returns true for technical category" do
    skill = skills(:technical_skills)
    assert skill.technical?
  end

  test "technical? returns false for non-technical category" do
    skill = skills(:soft_skills)
    assert_not skill.technical?
  end

  test "soft? returns true for soft category" do
    skill = skills(:soft_skills)
    assert skill.soft?
  end

  test "soft? returns false for non-soft category" do
    skill = skills(:technical_skills)
    assert_not skill.soft?
  end

  test "language? returns true for language category" do
    skill = skills(:language_skills)
    assert skill.language?
  end

  test "language? returns false for non-language category" do
    skill = skills(:technical_skills)
    assert_not skill.language?
  end

  # ============================================
  # SERIALIZATION TESTS
  # ============================================

  test "skill_names is serialized as JSON array" do
    skill = skills(:technical_skills)
    assert skill.skill_names.is_a?(Array), "skill_names should be an array"
  end

  test "skill_names can store and retrieve array" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    
    skill = Skill.create!(
      resume: resumes(:complete_resume),
      category: "technical",
      skill_names: ["Python", "Django", "FastAPI"]
    )
    
    skill.reload
    assert_equal ["Python", "Django", "FastAPI"], skill.skill_names
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content" do
    skill = skills(:arabic_skill)
    assert_equal "البرمجة", skill.name
    assert skill.skill_names.is_a?(Array)
  end
end
