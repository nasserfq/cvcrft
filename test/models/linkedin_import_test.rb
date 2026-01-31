require "test_helper"

class LinkedinImportTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    @user = users(:test_user)
    @linkedin_import = LinkedinImport.new(
      user: @user,
      original_filename: "test_linkedin.pdf",
      extracted_text: "John Doe\nSoftware Engineer"
    )
  end

  # ============================================
  # VALIDATION TESTS
  # ============================================

  test "should be valid with all required attributes" do
    assert @linkedin_import.valid?
  end

  test "should require user" do
    @linkedin_import.user = nil
    assert_not @linkedin_import.valid?
    assert_includes @linkedin_import.errors[:user], "must exist"
  end

  test "should require original_filename" do
    @linkedin_import.original_filename = nil
    assert_not @linkedin_import.valid?
    assert_includes @linkedin_import.errors[:original_filename], "can't be blank"
  end

  test "should validate status inclusion" do
    @linkedin_import.status = "invalid_status"
    assert_not @linkedin_import.valid?
    assert_includes @linkedin_import.errors[:status], "is not included in the list"
  end

  test "should accept valid statuses" do
    %w[pending processing completed failed].each do |status|
      @linkedin_import.status = status
      assert @linkedin_import.valid?, "#{status} should be a valid status"
    end
  end

  # ============================================
  # DEFAULT VALUES TESTS
  # ============================================

  test "should set default status to pending" do
    import = LinkedinImport.new
    assert_equal "pending", import.status
  end

  # ============================================
  # STATUS HELPER TESTS
  # ============================================

  test "pending? returns true when status is pending" do
    @linkedin_import.status = "pending"
    assert @linkedin_import.pending?
    assert_not @linkedin_import.processing?
    assert_not @linkedin_import.completed?
    assert_not @linkedin_import.failed?
  end

  test "processing? returns true when status is processing" do
    @linkedin_import.status = "processing"
    assert @linkedin_import.processing?
    assert_not @linkedin_import.pending?
    assert_not @linkedin_import.completed?
    assert_not @linkedin_import.failed?
  end

  test "completed? returns true when status is completed" do
    @linkedin_import.status = "completed"
    assert @linkedin_import.completed?
    assert_not @linkedin_import.pending?
    assert_not @linkedin_import.processing?
    assert_not @linkedin_import.failed?
  end

  test "failed? returns true when status is failed" do
    @linkedin_import.status = "failed"
    assert @linkedin_import.failed?
    assert_not @linkedin_import.pending?
    assert_not @linkedin_import.processing?
    assert_not @linkedin_import.completed?
  end

  # ============================================
  # STATE TRANSITION TESTS
  # ============================================

  test "mark_processing! updates status to processing" do
    @linkedin_import.save!
    @linkedin_import.mark_processing!
    assert_equal "processing", @linkedin_import.reload.status
  end

  test "mark_completed! updates status and stores parsed data" do
    @linkedin_import.save!
    parsed_data = {
      "complete_name" => "John Doe",
      "email" => "john@example.com",
      "professional_summary" => "Software engineer with 5 years experience"
    }

    @linkedin_import.mark_completed!(parsed_data)
    @linkedin_import.reload

    assert_equal "completed", @linkedin_import.status
    assert_equal parsed_data, @linkedin_import.parsed_data
  end

  test "mark_failed! updates status and stores error message" do
    @linkedin_import.save!
    @linkedin_import.mark_failed!("API connection failed")
    @linkedin_import.reload

    assert_equal "failed", @linkedin_import.status
    assert_equal "API connection failed", @linkedin_import.error_message
  end

  # ============================================
  # SCOPE TESTS
  # ============================================

  test "recent scope orders by created_at desc" do
    LinkedinImport.delete_all

    old_import = LinkedinImport.create!(
      user: @user,
      original_filename: "old.pdf",
      created_at: 2.days.ago
    )
    new_import = LinkedinImport.create!(
      user: @user,
      original_filename: "new.pdf",
      created_at: 1.hour.ago
    )

    recent = LinkedinImport.recent.limit(2)
    assert_equal new_import, recent.first
  end

  test "pending scope returns only pending imports" do
    @linkedin_import.save!
    completed = LinkedinImport.create!(
      user: @user,
      original_filename: "done.pdf",
      status: "completed"
    )

    pending_imports = LinkedinImport.pending.where(id: [ @linkedin_import.id, completed.id ])
    assert_includes pending_imports, @linkedin_import
    assert_not_includes pending_imports, completed
  end

  test "completed scope returns only completed imports" do
    @linkedin_import.save!
    completed = LinkedinImport.create!(
      user: @user,
      original_filename: "done.pdf",
      status: "completed",
      parsed_data: { "complete_name" => "Test" }
    )

    completed_imports = LinkedinImport.completed.where(id: [ @linkedin_import.id, completed.id ])
    assert_includes completed_imports, completed
    assert_not_includes completed_imports, @linkedin_import
  end

  test "processing scope returns only processing imports" do
    processing = LinkedinImport.create!(
      user: @user,
      original_filename: "processing.pdf",
      status: "processing"
    )
    @linkedin_import.save!

    processing_imports = LinkedinImport.processing
    assert_includes processing_imports, processing
    assert_not_includes processing_imports, @linkedin_import
  end

  test "failed scope returns only failed imports" do
    failed = LinkedinImport.create!(
      user: @user,
      original_filename: "failed.pdf",
      status: "failed",
      error_message: "Error"
    )
    @linkedin_import.save!

    failed_imports = LinkedinImport.failed
    assert_includes failed_imports, failed
    assert_not_includes failed_imports, @linkedin_import
  end

  # ============================================
  # ASSOCIATION TESTS
  # ============================================

  test "belongs to user" do
    assert_respond_to @linkedin_import, :user
    assert_equal @user, @linkedin_import.user
  end

  test "belongs to resume optionally" do
    assert_respond_to @linkedin_import, :resume
    assert_nil @linkedin_import.resume
  end

  test "can be associated with a resume" do
    resume = resumes(:complete_resume)
    @linkedin_import.resume = resume
    @linkedin_import.save!
    assert_equal resume, @linkedin_import.reload.resume
  end

  # ============================================
  # FIXTURE TESTS
  # ============================================

  test "fixtures are valid" do
    assert linkedin_imports(:pending_import).valid?
    assert linkedin_imports(:processing_import).valid?
    assert linkedin_imports(:completed_import).valid?
    assert linkedin_imports(:failed_import).valid?
  end

  test "completed fixture has parsed_data" do
    completed = linkedin_imports(:completed_import)
    assert completed.parsed_data.present?
    assert_equal "Ahmed Ali", completed.parsed_data["complete_name"]
  end

  test "failed fixture has error_message" do
    failed = linkedin_imports(:failed_import)
    assert failed.error_message.present?
  end
end
