class LinkedinPdfParserService
  class LinkedinPdfParseError < StandardError; end

  # A CV is a few pages. Caps keep a hostile upload from tying up the web
  # request or sending a huge prompt to the AI.
  MAX_PAGES = 20
  MAX_TEXT_CHARS = 60_000

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
    reader.pages.first(MAX_PAGES).each do |page|
      text_content << page.text
      break if text_content.sum(&:length) > MAX_TEXT_CHARS
    end

    # Join all pages with newlines
    raw_text = text_content.join("\n\n")

    # Clean up the text (remove excessive whitespace but preserve structure)
    clean_text(raw_text)[0, MAX_TEXT_CHARS]
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
