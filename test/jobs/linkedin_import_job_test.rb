require "test_helper"
require "sidekiq/testing"

class LinkedinImportJobTest < ActiveSupport::TestCase
  # ============================================
  # SETUP
  # ============================================

  def setup
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all

    @user = users(:test_user)
    @linkedin_import = LinkedinImport.create!(
      user: @user,
      original_filename: "test_linkedin.pdf",
      extracted_text: "John Doe\nSoftware Engineer at Tech Company\nExperience: 5 years"
    )
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  # ============================================
  # JOB ENQUEUEING TESTS
  # ============================================

  test "job is enqueued to Sidekiq" do
    assert_equal 0, LinkedinImportJob.jobs.size

    LinkedinImportJob.perform_async(@linkedin_import.id)

    assert_equal 1, LinkedinImportJob.jobs.size
  end

  test "job is enqueued with correct arguments" do
    LinkedinImportJob.perform_async(@linkedin_import.id)

    job = LinkedinImportJob.jobs.first
    assert_equal [ @linkedin_import.id ], job["args"]
  end

  # ============================================
  # JOB BEHAVIOR TESTS (inline mode)
  # ============================================

  test "job marks import as processing then completed on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      LinkedinImportJob.perform_async(@linkedin_import.id)
      @linkedin_import.reload

      assert_equal "completed", @linkedin_import.status
      assert @linkedin_import.parsed_data.present?
    end
  end

  test "job handles missing linkedin_import by raising RecordNotFound" do
    Sidekiq::Testing.inline! do
      assert_raises(ActiveRecord::RecordNotFound) do
        LinkedinImportJob.new.perform(-1)
      end
    end
  end

  test "job keeps import processing on API error so Sidekiq can retry" do
    stub_azure_openai_failure

    assert_raises(RuntimeError) do
      LinkedinImportJob.new.perform(@linkedin_import.id)
    end

    @linkedin_import.reload
    assert_equal "processing", @linkedin_import.status
    assert_nil @linkedin_import.error_message
  end

  test "retries exhausted marks import failed" do
    @linkedin_import.mark_processing!

    exhaust_retries([ @linkedin_import.id ], RuntimeError.new("API Error"))

    @linkedin_import.reload
    assert_equal "failed", @linkedin_import.status
    assert_equal "API Error", @linkedin_import.error_message
  end

  test "retries exhausted refunds the credit charged for the import" do
    charge_credit_for(@linkedin_import)
    balance = Billing::Credits.balance(@user)

    exhaust_retries([ @linkedin_import.id, @linkedin_import.charge_key ], RuntimeError.new("API Error"))

    assert_equal balance + Billing::UsageGate.cost(:document_ai), Billing::Credits.balance(@user)
  ensure
    ENV.delete("BILLING_ENABLED")
  end

  test "retries exhausted does not overwrite a completed import" do
    @linkedin_import.mark_completed!({ "complete_name" => "Done" })

    exhaust_retries([ @linkedin_import.id ], RuntimeError.new("late"))

    assert_equal "completed", @linkedin_import.reload.status
  end

  test "job does not parse a completed import again" do
    @linkedin_import.mark_completed!({ "complete_name" => "Done" })
    AiModel.expects(:complete).never

    LinkedinImportJob.new.perform(@linkedin_import.id)

    assert_equal "Done", @linkedin_import.reload.parsed_data["complete_name"]
  end

  test "job does not complete an import that timed out meanwhile" do
    import_id = @linkedin_import.id
    job = LinkedinImportJob.new
    job.define_singleton_method(:call_azure_openai_api) do |_text|
      LinkedinImport.fail_active!(import_id, "timed out")
      { "complete_name" => "Late" }
    end

    job.perform(import_id)

    assert_equal "failed", @linkedin_import.reload.status
    assert_equal "timed out", @linkedin_import.error_message
  end

  test "job stores parsed data on success" do
    Sidekiq::Testing.inline! do
      stub_azure_openai_success

      LinkedinImportJob.perform_async(@linkedin_import.id)
      @linkedin_import.reload

      assert @linkedin_import.parsed_data["complete_name"].present?
      assert @linkedin_import.parsed_data["professional_summary"].present?
      assert @linkedin_import.parsed_data["work_experiences"].is_a?(Array)
    end
  end

  # ============================================
  # HELPER METHODS
  # ============================================

  private

  def exhaust_retries(args, error)
    LinkedinImportJob.sidekiq_retries_exhausted_block.call({ "args" => args }, error)
  end

  def charge_credit_for(import)
    ENV["BILLING_ENABLED"] = "true"
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_column(:document_ai_count, UserUsageLimits::BASE_DOCUMENT_AI)
    assert_equal :credit, Billing::UsageGate.allow!(@user.reload, :document_ai, key: import.charge_key)
  end

  def stub_azure_openai_success
    mock_response = {
      "choices" => [
        {
          "message" => {
            "content" => {
              "complete_name" => "John Doe",
              "email" => "john@example.com",
              "phone_number" => "+1234567890",
              "city" => "San Francisco",
              "country" => "USA",
              "professional_summary" => "Experienced software engineer with 5 years of experience",
              "work_experiences" => [
                {
                  "job_title" => "Senior Software Engineer",
                  "company" => "Tech Company",
                  "start_date" => "2020-01",
                  "end_date" => "",
                  "is_current" => true,
                  "responsibilities" => [
                    "Led development team",
                    "Built scalable systems"
                  ]
                }
              ],
              "educations" => [
                {
                  "degree" => "Bachelor of Science in Computer Science",
                  "institution" => "Stanford University",
                  "end_date" => "2018"
                }
              ],
              "skills" => [
                {
                  "category" => "Technical",
                  "items" => [ "Ruby", "Python", "JavaScript" ]
                }
              ],
              "certifications" => []
            }.to_json
          }
        }
      ],
      "usage" => { "total_tokens" => 800 }
    }

    stub_ai_response(mock_response.dig("choices", 0, "message", "content"))
  end

  def stub_azure_openai_failure
    stub_ai_failure
  end
end
