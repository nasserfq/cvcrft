require "test_helper"

class CvGenerationPdfRegeneratorTest < ActiveSupport::TestCase
  GENERATED_DATA = { "professional_summary" => "Stored summary", "work_experiences" => [], "skills" => [],
                     "educations" => [], "certifications" => [], "languages" => [] }.freeze

  setup do
    @resume = resumes(:complete_resume)
    @user = @resume.user
    @pdf = Tempfile.new([ "cv", ".pdf" ])
    @pdf.write("new pdf")
    @pdf.flush
    AtsTemplatePdfService.stubs(:generate_pdf).returns({ path: @pdf.path, filename: "generated_cv.pdf" })
  end

  teardown do
    @pdf.close!
  end

  def create_generation(status: "completed", pdf_generated: true, ai_model: "gpt-4", generated_data: GENERATED_DATA, **attrs)
    metadata = { "pdf_data" => Base64.encode64("old"), "ats_template" => "harvard_classic" }
    metadata["pdf_generated"] = "true" if pdf_generated
    metadata["generated_data"] = generated_data if generated_data
    create_test_cv_generation(@user, resume: @resume, status: status, ai_model: ai_model,
                                     generated_content: "Stored summary", metadata: metadata, **attrs)
  end

  test "redraws the PDF from the stored data on the same row, without the AI" do
    target = create_generation
    AiModel.expects(:complete).never
    AtsTemplatePdfService.expects(:generate_pdf)
                         .with(@resume, GENERATED_DATA.deep_symbolize_keys, template: "harvard_classic")
                         .returns({ path: @pdf.path, filename: "generated_cv.pdf" })

    result = assert_no_difference -> { CvGeneration.count } do
      CvGenerationPdfRegenerator.call
    end

    assert_equal({ total: 1, success: 1, failed: 0 }, result)
    target.reload
    assert_equal "completed", target.status
    assert_equal "Stored summary", target.generated_content
    assert_equal Base64.encode64("new pdf"), target.metadata["pdf_data"]
    assert_equal GENERATED_DATA, target.metadata["generated_data"]
  end

  test "processes only completed AI generations with a generated PDF" do
    create_generation
    create_generation(pdf_generated: false)
    create_generation(status: "processing")
    create_generation(ai_model: "cv_builder")

    assert_equal({ total: 1, success: 1, failed: 0 }, CvGenerationPdfRegenerator.call)
  end

  test "a generation without stored data counts as failed and keeps its PDF" do
    target = create_generation(generated_data: nil)
    AtsTemplatePdfService.expects(:generate_pdf).never

    assert_equal({ total: 1, success: 0, failed: 1 }, CvGenerationPdfRegenerator.call)
    assert_equal Base64.encode64("old"), target.reload.metadata["pdf_data"]
  end

  test "a PDF that can't be drawn counts as failed, keeps the old PDF and the loop continues" do
    broken = create_generation(job_description: "First job description whose PDF will fail.")
    create_generation(job_description: "Second job description whose PDF will draw.")
    AtsTemplatePdfService.stubs(:generate_pdf).raises(RuntimeError, "boom").then
                         .returns({ path: @pdf.path, filename: "generated_cv.pdf" })

    assert_equal({ total: 2, success: 1, failed: 1 }, CvGenerationPdfRegenerator.call)
    assert_equal Base64.encode64("old"), broken.reload.metadata["pdf_data"]
  end

  test "returns zero counts when nothing matches" do
    assert_equal({ total: 0, success: 0, failed: 0 }, CvGenerationPdfRegenerator.call)
  end
end
