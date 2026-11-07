require "test_helper"
require "sidekiq/testing"

class LinkedinImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    sign_in @user
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  def teardown
    Sidekiq::Worker.clear_all
    ENV.delete("BILLING_ENABLED")
  end

  test "create refunds the credit when anything after the charge fails" do
    use_credit_for_next_import
    LinkedinPdfParserService.any_instance.stubs(:parse).returns("John Doe, Rails engineer")
    LinkedinImportJob.stubs(:perform_async).raises(RedisClient::CannotConnectError, "redis down")
    balance = Billing::Credits.balance(@user)

    assert_raises(RedisClient::CannotConnectError) do
      post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }
    end

    assert_equal balance, Billing::Credits.balance(@user)
    assert_equal "failed", @user.linkedin_imports.recent.first.status
  end

  test "create charges the import under its own key" do
    use_credit_for_next_import
    LinkedinPdfParserService.any_instance.stubs(:parse).returns("John Doe, Rails engineer")

    post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }

    assert_response :success
    import = LinkedinImport.find(JSON.parse(response.body)["id"])
    assert_equal [ import.id, import.charge_key ], LinkedinImportJob.jobs.last["args"]
    assert import.refund_charge!
  end

  test "create keeps no import when the charge is blocked after the early check" do
    use_credit_for_next_import
    @user.update_column(:credit_balance, 0)
    Billing::UsageGate.stubs(:available?).returns(true)
    LinkedinPdfParserService.any_instance.stubs(:parse).returns("John Doe, Rails engineer")

    assert_no_difference -> { LinkedinImport.count } do
      post linkedin_import_path(format: :json), params: { pdf_file: pdf_upload }
    end

    assert_response :too_many_requests
  end

  test "update is refused while the import is processing" do
    import = create_import(status: "processing", parsed_data: {})

    patch linkedin_import_update_path(import, format: :json), params: { parsed_data: { complete_name: "Edited" } }

    assert_response :unprocessable_entity
    assert_nil import.reload.parsed_data["complete_name"]
  end

  test "update saves edits on a completed import" do
    import = create_import

    patch linkedin_import_update_path(import, format: :json), params: { parsed_data: { complete_name: "Edited" } }

    assert_response :success
    assert_equal "Edited", import.reload.parsed_data["complete_name"]
  end

  test "save_to_cv twice returns the same resume" do
    import = create_import

    assert_difference -> { @user.resumes.count }, 1 do
      post linkedin_import_save_to_cv_path(import, format: :json)
      post linkedin_import_save_to_cv_path(import, format: :json)
    end

    assert_response :success
    assert_equal import.reload.resume_id, JSON.parse(response.body)["resume_id"]
  end

  private

  def create_import(status: "completed", parsed_data: { "complete_name" => "Ahmed Ali", "email" => "ahmed@example.com" })
    LinkedinImport.create!(user: @user, original_filename: "in.pdf", extracted_text: "text",
                           status: status, parsed_data: parsed_data)
  end

  def use_credit_for_next_import
    ENV["BILLING_ENABLED"] = "true"
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
  end

  def pdf_upload
    tempfile = Tempfile.new([ "linkedin", ".pdf" ])
    tempfile.write("%PDF-1.4\n%%EOF")
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "application/pdf")
  end
end
