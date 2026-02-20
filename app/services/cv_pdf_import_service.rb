class CvPdfImportService
  class CvPdfParseError < StandardError; end
  class ArabicContentError < StandardError; end
  class CorruptedFileError < StandardError; end

  # Arabic character ratio threshold (30% = reject)
  ARABIC_THRESHOLD = 0.3

  def initialize(file_path_or_io)
    @file = file_path_or_io
  end

  # Main entry point - extract and validate CV
  def parse
    text = extract_text
    language = detect_language(text)

    {
      text: text,
      language: language
    }
  end

  # Extract raw text from PDF
  def extract_text
    reader = PDF::Reader.new(@file)

    if reader.pages.empty?
      raise CorruptedFileError, "الملف فارغ أو تالف"
    end

    text_content = []
    reader.pages.each do |page|
      page_text = page.text
      text_content << page_text if page_text.present?
    end

    raw_text = text_content.join("\n\n")

    if raw_text.strip.empty?
      raise CorruptedFileError, "لم نتمكن من استخراج النص من الملف. قد يكون الملف عبارة عن صورة أو محمي"
    end

    clean_text(raw_text)
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::EncryptedPDFError => e
    raise CorruptedFileError, "الملف تالف أو محمي: #{e.message}"
  rescue PDF::Reader::UnsupportedFeatureError => e
    raise CorruptedFileError, "صيغة الملف غير مدعومة: #{e.message}"
  rescue IOError, Errno::ENOENT => e
    raise CvPdfParseError, "فشل في قراءة الملف: #{e.message}"
  end

  # Detect primary language of text
  def detect_language(text)
    return "unknown" if text.blank?

    # Count Arabic and Latin characters
    arabic_chars = text.scan(/[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/).length
    latin_chars = text.scan(/[a-zA-Z]/).length
    total_letters = arabic_chars + latin_chars

    return "unknown" if total_letters == 0

    arabic_ratio = arabic_chars.to_f / total_letters

    if arabic_ratio > ARABIC_THRESHOLD
      "ar"
    elsif arabic_ratio > 0.1
      "mixed"
    else
      "en"
    end
  end

  # Check if content is primarily Arabic (raises error if so)
  def validate_english_content!(text)
    language = detect_language(text)

    if language == "ar"
      raise ArabicContentError, "السيرة الذاتية مكتوبة بالعربية. يرجى تحميل سيرة ذاتية باللغة الإنجليزية"
    end

    language
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
