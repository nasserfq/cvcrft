require "test_helper"

class ResumeTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    # Skip PDF generation in tests
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    assert resumes(:complete_resume).valid?, "complete_resume fixture should be valid"
    assert resumes(:draft_resume).valid?, "draft_resume fixture should be valid"
    assert resumes(:minimal_resume).valid?, "minimal_resume fixture should be valid"
    assert resumes(:arabic_resume).valid?, "arabic_resume fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save resume without user_id" do
    resume = Resume.new(complete_name: "Test", email: "test@example.com")
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert_includes resume.errors[:user_id], "can't be blank"
  end

  test "should not save resume without complete_name" do
    resume = Resume.new(user: users(:test_user), email: "test@example.com")
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert_includes resume.errors[:complete_name], "can't be blank"
  end

  test "should not save resume without email" do
    resume = Resume.new(user: users(:test_user), complete_name: "Test User")
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert_includes resume.errors[:email], "can't be blank"
  end

  test "should not save resume with invalid email format" do
    resume = Resume.new(
      user: users(:test_user),
      complete_name: "Test User",
      email: "invalid-email"
    )
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert resume.errors[:email].any?
  end

  test "should not save resume with name too short" do
    resume = Resume.new(
      user: users(:test_user),
      complete_name: "A",
      email: "test@example.com"
    )
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert resume.errors[:complete_name].any?
  end

  test "should not save resume with name too long" do
    resume = Resume.new(
      user: users(:test_user),
      complete_name: "A" * 101,
      email: "test@example.com"
    )
    resume.skip_validations_for_pdf = false
    assert_not resume.valid?
    assert resume.errors[:complete_name].any?
  end

  test "should validate ats_score range" do
    resume = resumes(:complete_resume).dup
    resume.ats_score = 150
    assert_not resume.valid?
    assert resume.errors[:ats_score].any?

    resume.ats_score = 0
    assert_not resume.valid?
    assert resume.errors[:ats_score].any?

    resume.ats_score = 85
    resume.email = "unique-#{SecureRandom.hex}@example.com"
    assert resume.valid?
  end

  test "should allow nil ats_score" do
    resume = resumes(:complete_resume).dup
    resume.ats_score = nil
    resume.email = "unique-#{SecureRandom.hex}@example.com"
    assert resume.valid?
  end

  test "should allow professional_summary up to 1000 characters" do
    resume = resumes(:complete_resume)
    resume.professional_summary = "A" * 1000
    assert resume.valid?

    resume.professional_summary = "A" * 1001
    assert_not resume.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "resume belongs to user" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :user
    assert_instance_of User, resume.user
  end

  test "resume has many work_experiences" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :work_experiences
    assert resume.work_experiences.count >= 0
  end

  test "resume has many skills" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :skills
    assert resume.skills.count >= 0
  end

  test "resume has many educations" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :educations
    assert resume.educations.count >= 0
  end

  test "resume has many certifications" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :certifications
  end

  test "resume has many languages" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :languages
  end

  test "resume has many ai_translations" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :ai_translations
  end

  test "resume has many cv_generations" do
    resume = resumes(:complete_resume)
    assert_respond_to resume, :cv_generations
  end

  test "destroying resume destroys work_experiences" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    user = users(:test_user)
    resume = Resume.create!(
      user: user,
      complete_name: "Test User",
      email: "destroy-test@example.com"
    )
    resume.work_experiences.create!(
      company: "Test Co",
      job_title: "Developer",
      start_date: "2020-01"
    )

    assert_difference "WorkExperience.count", -1 do
      resume.destroy
    end
  end

  test "destroying resume destroys skills" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    user = users(:test_user)
    resume = Resume.create!(
      user: user,
      complete_name: "Test User",
      email: "destroy-skill-test@example.com"
    )
    resume.skills.create!(category: "technical", skill_names: [ "Ruby" ])

    assert_difference "Skill.count", -1 do
      resume.destroy
    end
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    resumes = Resume.recent
    dates = resumes.pluck(:created_at).compact
    assert_equal dates, dates.sort.reverse
  end

  test "by_ats_score scope orders by ats_score desc" do
    resumes = Resume.by_ats_score
    scores = resumes.where.not(ats_score: nil).pluck(:ats_score)
    assert_equal scores, scores.sort.reverse
  end

  test "drafts scope returns only drafts" do
    drafts = Resume.drafts
    drafts.each do |resume|
      assert resume.is_draft, "Expected #{resume.id} to be a draft"
    end
  end

  test "not_drafts scope excludes drafts" do
    not_drafts = Resume.not_drafts
    not_drafts.each do |resume|
      assert_not resume.is_draft, "Expected #{resume.id} to not be a draft"
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "draft? returns true for draft resumes" do
    resume = resumes(:draft_resume)
    assert resume.draft?
  end

  test "draft? returns false for non-draft resumes" do
    resume = resumes(:complete_resume)
    assert_not resume.draft?
  end

  test "can_be_resumed? returns true for drafts" do
    resume = resumes(:draft_resume)
    assert resume.can_be_resumed?
  end

  test "resume_data returns draft_data or empty hash" do
    draft = resumes(:draft_resume)
    assert draft.resume_data.is_a?(Hash)

    complete = resumes(:complete_resume)
    assert complete.resume_data.is_a?(Hash)
  end

  test "load_draft_data parses JSON fields correctly" do
    resume = resumes(:draft_resume)
    data = resume.load_draft_data
    assert data.is_a?(Hash)
  end

  test "save_draft updates resume correctly" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    resume = resumes(:minimal_resume)
    form_data = { "step" => 2, "skills" => [ "Ruby", "Rails" ] }

    resume.save_draft(form_data)
    resume.reload

    assert resume.is_draft
    assert_equal form_data, resume.draft_data
  end

  test "empty_starter_draft ignores default form placeholders in draft_data" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    resume = Resume.new(
      user: users(:test_user),
      complete_name: "nonq70007",
      email: "starter-placeholder@example.com",
      is_draft: true,
      draft_data: {
        "current_step" => 1,
        "work_experience" => [
          {
            "job_title" => "",
            "company" => "",
            "responsibilities" => [ "" ]
          }
        ].to_json
      }
    )

    assert resume.empty_starter_draft?
  end

  test "draft_data_has_meaningful_content detects real work experience entries" do
    resume = Resume.new(
      draft_data: {
        "work_experience" => [
          {
            "job_title" => "Engineer",
            "company" => "",
            "responsibilities" => [ "" ]
          }
        ].to_json
      }
    )

    assert resume.draft_data_has_meaningful_content?
  end

  # ============================================
  # NESTED ATTRIBUTES TESTS
  # ============================================

  test "accepts nested attributes for work_experiences" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    user = users(:test_user)
    resume = Resume.new(
      user: user,
      complete_name: "Test User",
      email: "nested-test@example.com",
      work_experiences_attributes: [
        { company: "Test Co", job_title: "Developer", start_date: "2020-01" }
      ]
    )

    assert resume.save
    assert_equal 1, resume.work_experiences.count
  end

  test "accepts nested attributes for skills" do
    Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

    user = users(:test_user)
    resume = Resume.new(
      user: user,
      complete_name: "Test User",
      email: "nested-skill-test@example.com",
      skills_attributes: [
        { category: "technical", skill_names: [ "Ruby" ] }
      ]
    )

    assert resume.save
    assert_equal 1, resume.skills.count
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content in all fields" do
    resume = resumes(:arabic_resume)
    assert_equal "سيرة ذاتية", resume.title
    assert_equal "مطور برمجيات", resume.target_position
    assert_equal "محمد أحمد", resume.complete_name
    assert_equal "جدة", resume.city
    assert_equal "السعودية", resume.country
    assert resume.professional_summary.include?("مطور برمجيات")
  end
end
