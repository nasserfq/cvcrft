require "test_helper"

class CvGenerationPdfRegeneratorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  def create_generation(status: "completed", pdf_generated: true, **attrs)
    metadata = pdf_generated ? { "pdf_generated" => "true" } : {}
    create_test_cv_generation(@user, status: status, metadata: metadata, **attrs)
  end

  test "processes only completed generations with a generated PDF" do
    target = create_generation
    create_generation(pdf_generated: false)
    create_generation(status: "processing")

    CvGeneratorJob.any_instance.expects(:perform)
      .with(target.job_description, @user.id, target.resume_id, { force_pdf_regeneration: true })
      .once

    result = CvGenerationPdfRegenerator.call

    assert_equal({ total: 1, success: 1, failed: 0 }, result)
  end

  test "counts a generation without a job description as failed and skips the job" do
    blank = create_generation
    blank.update_column(:job_description, "")

    CvGeneratorJob.any_instance.expects(:perform).never

    assert_equal({ total: 1, success: 0, failed: 1 }, CvGenerationPdfRegenerator.call)
  end

  test "a raising job counts as failed and the loop continues" do
    create_generation(job_description: "First job description that will fail.")
    create_generation(job_description: "Second job description that will succeed.")

    CvGeneratorJob.any_instance.stubs(:perform)
    CvGeneratorJob.any_instance.stubs(:perform)
      .with("First job description that will fail.", anything, anything, anything)
      .raises(StandardError, "boom")

    assert_equal({ total: 2, success: 1, failed: 1 }, CvGenerationPdfRegenerator.call)
  end

  test "returns zero counts when nothing matches" do
    CvGeneratorJob.any_instance.expects(:perform).never

    assert_equal({ total: 0, success: 0, failed: 0 }, CvGenerationPdfRegenerator.call)
  end
end
