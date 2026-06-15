require "test_helper"

class ProfessionalSummaryTextTest < ActiveSupport::TestCase
  test "extracts english_text from json blob" do
    raw = '{"english_text":"Experienced engineer","skills_extracted":[]}'
    assert_equal "Experienced engineer", ProfessionalSummaryText.normalize(raw)
  end

  test "extracts text from markdown fenced json" do
    raw = <<~JSON
      ```json
      {
        "english_text": "Product manager with 8 years of experience"
      }
      ```
    JSON

    assert_equal "Product manager with 8 years of experience", ProfessionalSummaryText.normalize(raw)
  end

  test "returns plain text unchanged" do
    assert_equal "Plain summary text", ProfessionalSummaryText.normalize("Plain summary text")
  end
end
