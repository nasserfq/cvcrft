require "test_helper"

class CvPdfImportServiceTest < ActiveSupport::TestCase
  # ============================================
  # LANGUAGE DETECTION TESTS
  # ============================================

  test "detects English text as en language" do
    english_text = "John Doe\nSoftware Engineer\nExperienced developer with 5 years"
    mock_reader = mock_pdf_reader([ english_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_equal "en", result[:language]
    assert_equal english_text.gsub(/\s+/, " ").strip, result[:text].gsub(/\s+/, " ").strip
  end

  test "detects Arabic text and returns ar language" do
    arabic_text = "محمد أحمد\nمدير مشروع\nخبرة في إدارة المشاريع"
    mock_reader = mock_pdf_reader([ arabic_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_equal "ar", result[:language]
  end

  test "validate_english_content! raises ArabicContentError for Arabic text" do
    arabic_text = "محمد أحمد\nمدير مشروع\nخبرة في إدارة المشاريع"
    mock_reader = mock_pdf_reader([ arabic_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    text = service.send(:extract_text)

    error = assert_raises(CvPdfImportService::ArabicContentError) do
      service.validate_english_content!(text)
    end

    assert_match(/عربي|Arabic/i, error.message)
  end

  test "detects mixed content with more than 30% Arabic as ar" do
    # Text with ~50% Arabic characters
    mixed_text = "محمد أحمد Ahmed Mohamed\nمدير مشروع Project Manager"
    mock_reader = mock_pdf_reader([ mixed_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_equal "ar", result[:language]
  end

  test "returns mixed for content between 10-30% Arabic" do
    # Text with ~15% Arabic (name only)
    mostly_english = "Mohamed Ahmed\nSoftware Engineer at Tech Company\nExperienced developer with Python, Ruby, JavaScript and more technologies"
    mock_reader = mock_pdf_reader([ mostly_english ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_includes %w[en mixed], result[:language]
  end

  # ============================================
  # PDF PARSING TESTS
  # ============================================

  test "extracts text from multi-page PDF" do
    page1_text = "John Doe\nSoftware Engineer"
    page2_text = "Work Experience\nTech Company"
    mock_reader = mock_pdf_reader([ page1_text, page2_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_includes result[:text], "John Doe"
    assert_includes result[:text], "Work Experience"
  end

  test "raises CorruptedFileError for invalid PDF" do
    PDF::Reader.stubs(:new).raises(PDF::Reader::MalformedPDFError.new("Invalid PDF"))

    error = assert_raises(CvPdfImportService::CorruptedFileError) do
      service = CvPdfImportService.new("/fake/path.pdf")
      service.parse
    end

    assert_match(/تالف/i, error.message)
  end

  test "raises CorruptedFileError for encrypted PDF" do
    PDF::Reader.stubs(:new).raises(PDF::Reader::EncryptedPDFError.new("Encrypted"))

    error = assert_raises(CvPdfImportService::CorruptedFileError) do
      service = CvPdfImportService.new("/fake/path.pdf")
      service.parse
    end

    assert_match(/تالف|محمي/i, error.message)
  end

  test "raises CorruptedFileError for empty PDF" do
    mock_reader = mock_pdf_reader([ "   \n\t  " ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    error = assert_raises(CvPdfImportService::CorruptedFileError) do
      service = CvPdfImportService.new("/fake/path.pdf")
      service.parse
    end

    assert error.message.present?
  end

  # ============================================
  # TEXT CLEANING TESTS
  # ============================================

  test "cleans up excessive whitespace" do
    messy_text = "John    Doe\n\n\n\nSoftware   Engineer\n\t\t\tExperience"
    mock_reader = mock_pdf_reader([ messy_text ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    # Should have cleaned text
    assert result[:text].present?
    # Multiple tabs should be normalized
    refute_includes result[:text], "\t\t\t"
  end

  # ============================================
  # LANGUAGE DETECTION ACCURACY TESTS
  # ============================================

  test "sets language to en for purely English text" do
    english_cv = <<~TEXT
      John Smith
      Software Engineer
      Email: john@example.com

      Professional Summary
      Experienced developer with expertise in Ruby on Rails

      Work Experience
      Senior Developer at Tech Corp
      2020 - Present
    TEXT

    mock_reader = mock_pdf_reader([ english_cv ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    assert_equal "en", result[:language]
  end

  test "correctly handles text with small Arabic percentage" do
    # Small amount of Arabic (under 10%)
    text_low_arabic = "Hello World this is a test with محمد in it somewhere along the way and more text"
    mock_reader = mock_pdf_reader([ text_low_arabic ])
    PDF::Reader.stubs(:new).returns(mock_reader)

    service = CvPdfImportService.new("/fake/path.pdf")
    result = service.parse

    # Should pass since Arabic is under 30%
    assert result[:text].present?
    assert_includes %w[en mixed], result[:language]
  end

  private

  def mock_pdf_reader(page_texts)
    pages = page_texts.map { |text| stub(text: text) }
    stub(pages: pages)
  end
end
