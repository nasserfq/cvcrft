require "test_helper"

class AiTranslationTest < ActiveSupport::TestCase
  # ============================================
  # FIXTURE & SETUP TESTS
  # ============================================

  test "fixtures are valid" do
    assert ai_translations(:completed_translation).valid?, "completed_translation fixture should be valid"
    assert ai_translations(:pending_translation).valid?, "pending_translation fixture should be valid"
    assert ai_translations(:failed_translation).valid?, "failed_translation fixture should be valid"
    assert ai_translations(:processing_translation).valid?, "processing_translation fixture should be valid"
    assert ai_translations(:job_description_translation).valid?, "job_description_translation fixture should be valid"
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should not save ai_translation without arabic_text" do
    translation = AiTranslation.new(
      user: users(:test_user),
      ai_model: "gpt-4",
      status: "pending"
    )
    assert_not translation.valid?
    assert_includes translation.errors[:arabic_text], "can't be blank"
  end

  test "should not save ai_translation with arabic_text too short" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "abcd", # 4 chars; the minimum is 5
      ai_model: "gpt-4",
      status: "pending"
    )
    assert_not translation.valid?
    assert translation.errors[:arabic_text].any?
  end

  test "should not save ai_translation with arabic_text too long" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "A" * 5001,
      ai_model: "gpt-4",
      status: "pending"
    )
    assert_not translation.valid?
    assert translation.errors[:arabic_text].any?
  end

  test "should not save ai_translation without ai_model" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      status: "pending"
    )
    assert_not translation.valid?
    assert_includes translation.errors[:ai_model], "can't be blank"
  end

  test "should validate status inclusion" do
    valid_statuses = %w[pending processing completed failed]

    valid_statuses.each do |status|
      translation = AiTranslation.new(
        user: users(:test_user),
        arabic_text: "نص عربي طويل بما يكفي للترجمة",
        ai_model: "gpt-4",
        status: status
      )
      assert translation.valid?, "#{status} should be a valid status"
    end
  end

  test "should reject invalid status" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      ai_model: "gpt-4",
      status: "invalid_status"
    )
    assert_not translation.valid?
    assert translation.errors[:status].any?
  end

  test "should validate translation_quality inclusion" do
    valid_qualities = %w[low medium high]

    valid_qualities.each do |quality|
      translation = AiTranslation.new(
        user: users(:test_user),
        arabic_text: "نص عربي طويل بما يكفي للترجمة",
        ai_model: "gpt-4",
        status: "completed",
        translation_quality: quality
      )
      assert translation.valid?, "#{quality} should be a valid translation quality"
    end
  end

  test "should allow nil translation_quality" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      ai_model: "gpt-4",
      status: "pending",
      translation_quality: nil
    )
    assert translation.valid?
  end

  test "should validate tokens_used is positive" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      ai_model: "gpt-4",
      status: "completed",
      tokens_used: -10
    )
    assert_not translation.valid?
    assert translation.errors[:tokens_used].any?
  end

  test "should allow nil tokens_used" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      ai_model: "gpt-4",
      status: "pending",
      tokens_used: nil
    )
    assert translation.valid?
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "ai_translation belongs to user" do
    translation = ai_translations(:completed_translation)
    assert_respond_to translation, :user
    assert_instance_of User, translation.user
  end

  test "ai_translation can optionally belong to resume" do
    translation = ai_translations(:completed_translation)
    assert_respond_to translation, :resume

    # Test with resume
    assert translation.resume.present?

    # Test without resume
    no_resume_translation = ai_translations(:job_description_translation)
    assert_nil no_resume_translation.resume
    assert no_resume_translation.valid?
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    translations = AiTranslation.recent
    dates = translations.pluck(:created_at).compact
    assert_equal dates, dates.sort.reverse
  end

  test "by_status scope filters by status" do
    completed = AiTranslation.by_status("completed")
    completed.each do |translation|
      assert_equal "completed", translation.status
    end
  end

  test "completed scope returns only completed translations" do
    completed = AiTranslation.completed
    completed.each do |translation|
      assert_equal "completed", translation.status
    end
  end

  test "failed scope returns only failed translations" do
    failed = AiTranslation.failed
    failed.each do |translation|
      assert_equal "failed", translation.status
    end
  end

  # ============================================
  # METHOD TESTS
  # ============================================

  test "processing? returns true for processing status" do
    translation = ai_translations(:processing_translation)
    assert translation.processing?
  end

  test "processing? returns false for non-processing status" do
    translation = ai_translations(:completed_translation)
    assert_not translation.processing?
  end

  test "completed? returns true for completed status" do
    translation = ai_translations(:completed_translation)
    assert translation.completed?
  end

  test "completed? returns false for non-completed status" do
    translation = ai_translations(:pending_translation)
    assert_not translation.completed?
  end

  test "failed? returns true for failed status" do
    translation = ai_translations(:failed_translation)
    assert translation.failed?
  end

  test "failed? returns false for non-failed status" do
    translation = ai_translations(:completed_translation)
    assert_not translation.failed?
  end

  test "pending? returns true for pending status" do
    translation = ai_translations(:pending_translation)
    assert translation.pending?
  end

  test "pending? returns false for non-pending status" do
    translation = ai_translations(:completed_translation)
    assert_not translation.pending?
  end

  test "has_quality_score? returns true when translation_quality is present" do
    translation = ai_translations(:completed_translation)
    assert translation.has_quality_score?
  end

  test "has_quality_score? returns false when translation_quality is blank" do
    translation = ai_translations(:pending_translation)
    assert_not translation.has_quality_score?
  end

  test "estimated_cost calculates for gpt-4" do
    translation = ai_translations(:completed_translation)
    cost = translation.estimated_cost
    assert cost.is_a?(Numeric)
    assert cost > 0
  end

  test "estimated_cost calculates for gpt-3.5-turbo" do
    translation = ai_translations(:job_description_translation)
    cost = translation.estimated_cost
    assert cost.is_a?(Numeric)
    assert cost > 0
  end

  test "estimated_cost returns 0 when tokens_used is nil" do
    translation = ai_translations(:pending_translation)
    assert_equal 0, translation.estimated_cost
  end

  # ============================================
  # CALLBACK TESTS
  # ============================================

  test "set_default_status sets pending on create" do
    translation = AiTranslation.new(
      user: users(:test_user),
      arabic_text: "نص عربي طويل بما يكفي للترجمة",
      ai_model: "gpt-4",
      status: nil  # Explicitly nil to test callback
    )
    # Call the callback manually since validation happens first
    translation.send(:set_default_status)
    assert_equal "pending", translation.status
  end

  # ============================================
  # ARABIC CONTENT TESTS
  # ============================================

  test "supports Arabic text content" do
    translation = ai_translations(:completed_translation)
    assert translation.arabic_text.match?(/[\u0600-\u06FF]/)
  end
end
