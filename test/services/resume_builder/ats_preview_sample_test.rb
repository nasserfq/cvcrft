require "test_helper"

class ResumeBuilder::AtsPreviewSampleTest < ActiveSupport::TestCase
  AtsStylePresets::AtsStyleCatalog.styles.map(&:key).each do |key|
    test "#{key} renders the preview sample without database records" do
      sample = AtsStylePresets::AtsPreviewSample
      result = AtsTemplatePdfService.generate_pdf(sample.resume, sample.data, template: key)

      assert File.exist?(result[:path])
      assert_operator File.size(result[:path]), :>, 0
      assert_equal "sara-al-ahmad_resume.pdf", result[:filename]
    ensure
      File.delete(result[:path]) if result && File.exist?(result[:path])
    end
  end
end
