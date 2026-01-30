class LinkedinPdfParserService
  class LinkedinPdfParseError < StandardError; end

  def initialize(file_path_or_io)
    @file = file_path_or_io
  end

  # Main entry point - extract raw text from LinkedIn PDF
  def parse
    extract_text
  end

  # Extract raw text from LinkedIn PDF
  def extract_text
    reader = PDF::Reader.new(@file)

    text_content = []
    reader.pages.each do |page|
      text_content << page.text
    end

    # Join all pages with newlines
    raw_text = text_content.join("\n\n")

    # Clean up the text (remove excessive whitespace but preserve structure)
    clean_text(raw_text)
  rescue PDF::Reader::MalformedPDFError => e
    raise LinkedinPdfParseError, "Invalid PDF file: #{e.message}"
  rescue => e
    raise LinkedinPdfParseError, "Failed to read PDF: #{e.message}"
  end

  private

  def clean_text(text)
    # Remove null characters
    text = text.gsub("\u0000", "")

    # Normalize whitespace (but preserve newlines for structure)
    text = text.gsub(/[^\S\n]+/, " ")

    # Remove excessive blank lines (more than 2)
    text = text.gsub(/\n{3,}/, "\n\n")

    # Trim each line
    text = text.lines.map(&:strip).join("\n")

    # Remove completely empty lines at start/end
    text.strip
  end
end
