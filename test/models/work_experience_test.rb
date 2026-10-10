require "test_helper"

class WorkExperienceTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert work_experiences(:current_job).valid?, "current_job fixture should be valid"
    assert work_experiences(:past_job).valid?, "past_job fixture should be valid"
    assert work_experiences(:internship).valid?, "internship fixture should be valid"
    assert work_experiences(:arabic_experience).valid?, "arabic_experience fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save work experience without company" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      job_title: "Developer",
      start_date: "2020-01"
    )
    assert_not we.valid?
    assert_includes we.errors[:company], "can't be blank"
  end

  test "should not save work experience without job_title" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "Test Company",
      start_date: "2020-01"
    )
    assert_not we.valid?
    assert_includes we.errors[:job_title], "can't be blank"
  end

  test "should not save work experience without start_date" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "Test Company",
      job_title: "Developer"
    )
    assert_not we.valid?
    assert_includes we.errors[:start_date], "can't be blank"
  end

  test "should not save work experience with company name too short" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "A",
      job_title: "Developer",
      start_date: "2020-01"
    )
    assert_not we.valid?
    assert we.errors[:company].any?
  end

  test "should not save work experience with company name too long" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "A" * 101,
      job_title: "Developer",
      start_date: "2020-01"
    )
    assert_not we.valid?
    assert we.errors[:company].any?
  end

  test "end_date must be after start_date" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "Test Company",
      job_title: "Developer",
      start_date: "2020-06",
      end_date: "2020-01"
    )
    assert_not we.valid?
    assert_includes we.errors[:end_date], "must be after start date"
  end

  test "start_date cannot be in the future" do
    future_date = (Date.current + 1.year).strftime("%Y-%m")
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "Test Company",
      job_title: "Developer",
      start_date: future_date
    )
    assert_not we.valid?
    assert_includes we.errors[:start_date], "cannot be in the future"
  end

  test "should allow nil end_date for current job" do
    we = WorkExperience.new(
      resume: resumes(:complete_resume),
      company: "Current Company",
      job_title: "Developer",
      start_date: "2020-01",
      end_date: nil,
      is_current: true
    )
    assert we.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "work experience belongs to resume" do
    we = work_experiences(:current_job)
    assert_respond_to we, :resume
    assert_instance_of Resume, we.resume
  end

  test "work experience can belong to ai_translation" do
    we = work_experiences(:current_job)
    assert_respond_to we, :ai_translation
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "chronological scope orders by start_date desc" do
    experiences = WorkExperience.chronological
    dates = experiences.pluck(:start_date).compact
    assert_equal dates, dates.sort.reverse
  end

  test "current scope returns only current jobs" do
    current = WorkExperience.current
    current.each do |we|
      assert_nil we.end_date, "Expected end_date to be nil for #{we.id}"
    end
  end

  test "past scope returns only past jobs" do
    past = WorkExperience.past
    past.each do |we|
      assert_not_nil we.end_date, "Expected end_date to be present for #{we.id}"
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "duration calculates years correctly" do
    we = work_experiences(:past_job)
    duration = we.duration
    assert duration.is_a?(Numeric)
    assert duration >= 0
  end

  test "duration returns 0 for invalid dates" do
    we = WorkExperience.new(start_date: "invalid")
    assert_equal 0, we.duration
  end

  test "duration handles current job with no end_date" do
    we = work_experiences(:current_job)
    duration = we.duration
    assert duration.is_a?(Numeric)
    assert duration >= 0
  end

  test "current? returns true when end_date is blank" do
    we = work_experiences(:current_job)
    assert we.current?
  end

  test "current? returns true when is_current is true" do
    we = work_experiences(:current_job)
    we.is_current = true
    assert we.current?
  end

  test "current? returns false when end_date is present and is_current is false" do
    we = work_experiences(:past_job)
    we.is_current = false
    assert_not we.current?
  end

  test "needs_translation? returns true when english_description is blank" do
    we = work_experiences(:arabic_experience)
    assert we.needs_translation?
  end

  test "needs_translation? returns false when english_description is present" do
    we = work_experiences(:current_job)
    assert_not we.needs_translation?
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic content" do
    we = work_experiences(:arabic_experience)
    assert_equal "شركة التقنية العربية", we.company
    assert_equal "مطور برمجيات أول", we.job_title
    assert we.arabic_description.include?("تطوير")
  end

  # ============================================
  # SKIP VALIDATIONS TESTS
  # ============================================

  test "skip_validations_for_pdf delegates to resume" do
    Resume.any_instance.stubs(:skip_validations_for_pdf).returns(true)

    we = work_experiences(:current_job)
    assert we.skip_validations_for_pdf
  end
end
