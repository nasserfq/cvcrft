require "test_helper"

class DataRetentionJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user)
  end

  test "deletes OTP codes older than one day and keeps recent ones" do
    old_otp = create_otp(created_at: 2.days.ago)
    recent_otp = create_otp(created_at: 2.hours.ago)

    DataRetentionJob.perform_now

    assert_not OtpVerification.exists?(old_otp.id)
    assert OtpVerification.exists?(recent_otp.id)
  end

  test "deletes failed analyses and imports older than 30 days only" do
    [ CvAnalysis, CvImport, LinkedinImport ].each do |model|
      old_failed = create_record(model, status: "failed", created_at: 31.days.ago)
      old_completed = create_record(model, status: "completed", created_at: 31.days.ago)
      new_failed = create_record(model, status: "failed", created_at: 29.days.ago)

      DataRetentionJob.perform_now

      assert_not model.exists?(old_failed.id), "#{model} old failed row should be deleted"
      assert model.exists?(old_completed.id), "#{model} old completed row should be kept"
      assert model.exists?(new_failed.id), "#{model} recent failed row should be kept"
    end
  end

  test "clears extracted text on rows older than 30 days only" do
    [ CvAnalysis, CvImport, LinkedinImport ].each do |model|
      old_completed = create_record(model, status: "completed", created_at: 31.days.ago)
      new_completed = create_record(model, status: "completed", created_at: 29.days.ago)

      DataRetentionJob.perform_now

      assert_nil old_completed.reload.extracted_text, "#{model} old text should be cleared"
      assert_equal "CV text", new_completed.reload.extracted_text, "#{model} recent text should be kept"
    end
  end

  test "keeps the rest of an old record when clearing its text" do
    analysis = create_record(CvAnalysis, status: "completed", created_at: 40.days.ago)
    analysis.update_columns(analysis_results: { "overall_score" => 77 })

    DataRetentionJob.perform_now

    analysis.reload
    assert_nil analysis.extracted_text
    assert_equal 77, analysis.overall_score
    assert_equal "cv.pdf", analysis.original_filename
  end

  test "does not touch cv generations or their pdf data" do
    generation = cv_generations(:completed_generation)
    generation.update_columns(created_at: 1.year.ago, metadata: generation.metadata.merge("pdf_data" => "JVBERi0xLjQK"))
    before = generation.reload.attributes

    DataRetentionJob.perform_now

    assert_equal before, generation.reload.attributes
  end

  test "returns counts for each step" do
    create_otp(created_at: 3.days.ago)
    create_record(CvImport, status: "failed", created_at: 60.days.ago)
    create_record(CvImport, status: "completed", created_at: 60.days.ago)

    counts = DataRetentionJob.perform_now

    assert_operator counts[:otp_verifications_deleted], :>=, 1
    assert_operator counts[:cv_imports_failed_deleted], :>=, 1
    assert_operator counts[:cv_imports_text_cleared], :>=, 1
    assert counts.values.all? { |count| count.is_a?(Integer) }
  end

  test "logs counts and no record content" do
    otp = create_otp(created_at: 3.days.ago)
    create_record(CvAnalysis, status: "completed", created_at: 60.days.ago)

    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    begin
      DataRetentionJob.perform_now
    ensure
      Rails.logger = original_logger
    end

    assert_includes output.string, "otp_verifications_deleted="
    assert_not_includes output.string, otp.email
    assert_not_includes output.string, "CV text"
  end

  test "is scheduled daily in config/schedule.yml" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    assert_equal "DataRetentionJob", schedule.dig("data_retention", "class")
    assert_equal "15 3 * * *", schedule.dig("data_retention", "cron")
  end

  private

  def create_otp(created_at:)
    otp = OtpVerification.create!(
      email: "retention-#{SecureRandom.hex(4)}@example.com",
      otp_code: "123456",
      expires_at: 10.minutes.from_now
    )
    otp.update_columns(created_at: created_at)
    otp
  end

  def create_record(model, status:, created_at:)
    record = model.create!(user: @user, original_filename: "cv.pdf", extracted_text: "CV text", status: status)
    record.update_columns(created_at: created_at)
    record
  end
end
