require "test_helper"

class CvImportTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    @user = users(:test_user)
    @cv_import = CvImport.new(
      user: @user,
      original_filename: "test_cv.pdf",
      extracted_text: "John Doe\nSoftware Engineer"
    )
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should be valid with all required attributes" do
    assert @cv_import.valid?
  end

  test "should require user" do
    @cv_import.user = nil
    assert_not @cv_import.valid?
    assert_includes @cv_import.errors[:user], "must exist"
  end

  test "should require original_filename" do
    @cv_import.original_filename = nil
    assert_not @cv_import.valid?
    assert_includes @cv_import.errors[:original_filename], "can't be blank"
  end

  test "should validate status inclusion" do
    @cv_import.status = "invalid_status"
    assert_not @cv_import.valid?
    assert_includes @cv_import.errors[:status], "is not included in the list"
  end

  test "should accept valid statuses" do
    %w[pending processing completed failed].each do |status|
      @cv_import.status = status
      assert @cv_import.valid?, "#{status} should be a valid status"
    end
  end

  test "should validate detected_language inclusion when present" do
    @cv_import.detected_language = "invalid_lang"
    assert_not @cv_import.valid?
    assert_includes @cv_import.errors[:detected_language], "is not included in the list"
  end

  test "should accept valid languages" do
    %w[en ar mixed unknown].each do |lang|
      @cv_import.detected_language = lang
      assert @cv_import.valid?, "#{lang} should be a valid language"
    end
  end

  test "should allow nil detected_language" do
    @cv_import.detected_language = nil
    assert @cv_import.valid?
  end

  # ============================================
  # DEFAULT VALUES TESTS
  # ============================================

  test "should set default status to pending" do
    import = CvImport.new
    assert_equal "pending", import.status
  end

  # ============================================
  # STATUS HELPER TESTS
  # ============================================

  test "pending? returns true when status is pending" do
    @cv_import.status = "pending"
    assert @cv_import.pending?
    assert_not @cv_import.processing?
    assert_not @cv_import.completed?
    assert_not @cv_import.failed?
  end

  test "processing? returns true when status is processing" do
    @cv_import.status = "processing"
    assert @cv_import.processing?
    assert_not @cv_import.pending?
    assert_not @cv_import.completed?
    assert_not @cv_import.failed?
  end

  test "completed? returns true when status is completed" do
    @cv_import.status = "completed"
    assert @cv_import.completed?
    assert_not @cv_import.pending?
    assert_not @cv_import.processing?
    assert_not @cv_import.failed?
  end

  test "failed? returns true when status is failed" do
    @cv_import.status = "failed"
    assert @cv_import.failed?
    assert_not @cv_import.pending?
    assert_not @cv_import.processing?
    assert_not @cv_import.completed?
  end

  # ============================================
  # LANGUAGE HELPER TESTS
  # ============================================

  test "arabic? returns true when detected_language is ar" do
    @cv_import.detected_language = "ar"
    assert @cv_import.arabic?
    assert_not @cv_import.english?
  end

  test "english? returns true when detected_language is en" do
    @cv_import.detected_language = "en"
    assert @cv_import.english?
    assert_not @cv_import.arabic?
  end

  # ============================================
  # STATUS TRANSITION TESTS
  # ============================================

  test "mark_processing! updates status to processing" do
    @cv_import.save!
    @cv_import.mark_processing!
    assert_equal "processing", @cv_import.status
  end

  test "mark_completed! updates status and parsed_data" do
    @cv_import.save!
    parsed_data = { "complete_name" => "John Doe", "email" => "john@example.com" }

    @cv_import.mark_completed!(parsed_data)

    assert_equal "completed", @cv_import.status
    assert_equal parsed_data, @cv_import.parsed_data
    assert_nil @cv_import.error_message
  end

  test "mark_completed! clears previous error_message" do
    @cv_import.save!
    @cv_import.update!(error_message: "Previous error")

    @cv_import.mark_completed!({ "complete_name" => "John Doe" })

    assert_nil @cv_import.error_message
  end

  test "mark_failed! updates status and error_message" do
    @cv_import.save!
    error = "Failed to parse PDF"

    @cv_import.mark_failed!(error)

    assert_equal "failed", @cv_import.status
    assert_equal error, @cv_import.error_message
  end

  test "mark_language! updates detected_language" do
    @cv_import.save!
    @cv_import.mark_language!("ar")
    assert_equal "ar", @cv_import.detected_language
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    imports = CvImport.recent
    assert imports.to_sql.include?("ORDER BY")
    assert imports.to_sql.include?("created_at")
    assert imports.to_sql.include?("DESC")
  end

  test "pending scope returns only pending imports" do
    pending = cv_imports(:pending_import)
    assert_includes CvImport.pending, pending
    assert_not_includes CvImport.pending, cv_imports(:completed_import)
  end

  test "completed scope returns only completed imports" do
    completed = cv_imports(:completed_import)
    assert_includes CvImport.completed, completed
    assert_not_includes CvImport.completed, cv_imports(:pending_import)
  end

  test "failed scope returns only failed imports" do
    failed = cv_imports(:failed_import)
    assert_includes CvImport.failed, failed
    assert_not_includes CvImport.failed, cv_imports(:pending_import)
  end

  test "arabic scope returns only arabic imports" do
    arabic = cv_imports(:arabic_import)
    assert_includes CvImport.arabic, arabic
    assert_not_includes CvImport.arabic, cv_imports(:completed_import)
  end

  test "english scope returns only english imports" do
    english = cv_imports(:completed_import)
    assert_includes CvImport.english, english
    assert_not_includes CvImport.english, cv_imports(:arabic_import)
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "belongs to user" do
    assert_respond_to @cv_import, :user
    assert_equal @user, @cv_import.user
  end

  test "belongs to resume optionally" do
    assert_respond_to @cv_import, :resume
    @cv_import.resume = nil
    assert @cv_import.valid?
  end
end
