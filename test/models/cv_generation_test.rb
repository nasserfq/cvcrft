require "test_helper"

class CvGenerationTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert cv_generations(:completed_generation).valid?, "completed_generation fixture should be valid"
    assert cv_generations(:processing_generation).valid?, "processing_generation fixture should be valid"
    assert cv_generations(:failed_generation).valid?, "failed_generation fixture should be valid"
    assert cv_generations(:draft_generation).valid?, "draft_generation fixture should be valid"
    assert cv_generations(:cv_builder_generation).valid?, "cv_builder_generation fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save cv_generation without job_description" do
    generation = CvGeneration.new(
      user: users(:test_user),
      ai_model: "gpt-4",
      status: "processing"
    )
    assert_not generation.valid?
    assert_includes generation.errors[:job_description], "can't be blank"
  end

  test "should not save cv_generation with job_description too short" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "short",
      ai_model: "gpt-4",
      status: "processing"
    )
    assert_not generation.valid?
    assert generation.errors[:job_description].any?
  end

  test "should not save cv_generation with job_description too long" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "A" * 5001,
      ai_model: "gpt-4",
      status: "processing"
    )
    assert_not generation.valid?
    assert generation.errors[:job_description].any?
  end

  test "should not save cv_generation without ai_model" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      status: "processing"
    )
    assert_not generation.valid?
    assert_includes generation.errors[:ai_model], "can't be blank"
  end

  test "should not save cv_generation without status" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      ai_model: "gpt-4"
    )
    assert_not generation.valid?
    assert_includes generation.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    valid_statuses = %w[processing completed failed cancelled draft]

    valid_statuses.each do |status|
      generation = CvGeneration.new(
        user: users(:test_user),
        job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
        ai_model: "gpt-4",
        status: status
      )
      assert generation.valid?, "#{status} should be a valid status"
    end
  end

  test "should reject invalid status" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      ai_model: "gpt-4",
      status: "invalid_status"
    )
    assert_not generation.valid?
    assert generation.errors[:status].any?
  end

  test "should validate tokens_used is non-negative" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      ai_model: "gpt-4",
      status: "completed",
      tokens_used: -10
    )
    assert_not generation.valid?
    assert generation.errors[:tokens_used].any?
  end

  test "should allow nil tokens_used" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      ai_model: "gpt-4",
      status: "processing",
      tokens_used: nil
    )
    assert generation.valid?
  end

  test "should allow zero tokens_used" do
    generation = CvGeneration.new(
      user: users(:test_user),
      job_description: "Looking for a software engineer with experience in Ruby on Rails development.",
      ai_model: "gpt-4",
      status: "processing",
      tokens_used: 0
    )
    assert generation.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "cv_generation belongs to user" do
    generation = cv_generations(:completed_generation)
    assert_respond_to generation, :user
    assert_instance_of User, generation.user
  end

  test "cv_generation can optionally belong to resume" do
    generation = cv_generations(:completed_generation)
    assert_respond_to generation, :resume

    # Test with resume
    assert generation.resume.present?

    # Test without resume
    no_resume_gen = cv_generations(:processing_generation)
    assert_nil no_resume_gen.resume
    assert no_resume_gen.valid?
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    generations = CvGeneration.recent
    dates = generations.pluck(:created_at).compact
    assert_equal dates, dates.sort.reverse
  end

  test "by_status scope filters by status" do
    completed = CvGeneration.by_status("completed")
    completed.each do |gen|
      assert_equal "completed", gen.status
    end
  end

  test "completed scope returns only completed generations" do
    completed = CvGeneration.completed
    completed.each do |gen|
      assert_equal "completed", gen.status
    end
  end

  test "processing scope returns only processing generations" do
    processing = CvGeneration.processing
    processing.each do |gen|
      assert_equal "processing", gen.status
    end
  end

  test "failed scope returns only failed generations" do
    failed = CvGeneration.failed
    failed.each do |gen|
      assert_equal "failed", gen.status
    end
  end

  test "drafts scope returns only draft generations" do
    drafts = CvGeneration.drafts
    drafts.each do |gen|
      assert gen.is_draft
    end
  end

  test "not_drafts scope excludes draft generations" do
    not_drafts = CvGeneration.not_drafts
    not_drafts.each do |gen|
      assert_not gen.is_draft
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "completed? returns true for completed status" do
    generation = cv_generations(:completed_generation)
    assert generation.completed?
  end

  test "completed? returns false for non-completed status" do
    generation = cv_generations(:processing_generation)
    assert_not generation.completed?
  end

  test "processing? returns true for processing status" do
    generation = cv_generations(:processing_generation)
    assert generation.processing?
  end

  test "processing? returns false for non-processing status" do
    generation = cv_generations(:completed_generation)
    assert_not generation.processing?
  end

  test "failed? returns true for failed status" do
    generation = cv_generations(:failed_generation)
    assert generation.failed?
  end

  test "failed? returns false for non-failed status" do
    generation = cv_generations(:completed_generation)
    assert_not generation.failed?
  end

  test "cancelled? returns true for cancelled status" do
    generation = CvGeneration.new(status: "cancelled")
    assert generation.cancelled?
  end

  test "cancelled? returns false for non-cancelled status" do
    generation = cv_generations(:completed_generation)
    assert_not generation.cancelled?
  end

  test "draft? returns true when is_draft is true" do
    generation = cv_generations(:draft_generation)
    assert generation.draft?
  end

  test "draft? returns true when status is draft" do
    generation = CvGeneration.new(status: "draft")
    assert generation.draft?
  end

  test "draft? returns false for non-draft" do
    generation = cv_generations(:completed_generation)
    assert_not generation.draft?
  end

  test "can_be_resumed? returns true for drafts" do
    generation = cv_generations(:draft_generation)
    assert generation.can_be_resumed?
  end

  test "resume_data returns draft_data or empty hash" do
    draft = cv_generations(:draft_generation)
    assert draft.resume_data.is_a?(Hash)

    complete = cv_generations(:completed_generation)
    assert complete.resume_data.is_a?(Hash)
  end

  test "save_draft updates generation correctly" do
    generation = cv_generations(:processing_generation)
    form_data = { "step" => 2, "skills" => [ "Ruby", "Rails" ] }

    generation.save_draft(form_data)
    generation.reload

    assert generation.is_draft
    assert_equal "draft", generation.status
    assert_equal form_data, generation.draft_data
  end

  test "complete_draft updates generation correctly" do
    generation = cv_generations(:draft_generation)

    generation.complete_draft
    generation.reload

    assert_not generation.is_draft
    assert_equal "processing", generation.status
  end

  # ============================================
  # METADATA TESTS
  # ============================================

  test "metadata stores source correctly" do
    generation = cv_generations(:completed_generation)
    assert_equal "job_description", generation.metadata["source"]

    cv_builder_gen = cv_generations(:cv_builder_generation)
    assert_equal "cv_builder", cv_builder_gen.metadata["source"]
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic job description" do
    generation = cv_generations(:failed_generation)
    assert generation.job_description.match?(/[\u0600-\u06FF]/)
    assert generation.valid?
  end
end
