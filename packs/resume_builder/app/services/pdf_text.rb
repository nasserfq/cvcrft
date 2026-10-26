# Prawn's built-in Helvetica can only draw Windows-1252, and Prawn raises on
# anything else (Ł, ✓, →, emoji, zero-width or bidi control characters). Every
# builder/ATS PDF keeps Helvetica (ATS-safe), so all text goes through here
# first: characters 1252 has stay, compatibility forms fold (NFKC), close
# look-alikes replace the rest, and whatever still cannot be drawn is dropped.
module PdfText
  ENCODING = Encoding::Windows_1252

  REPLACEMENTS = {
    "Ł" => "L", "ł" => "l", "ı" => "i", "İ" => "I", "ß" => "ss",
    "→" => "->", "⇒" => "=>", "⟶" => "->", "←" => "<-", "⇐" => "<=", "↔" => "<->",
    "✓" => "-", "✔" => "-", "☑" => "-", "✗" => "-", "✘" => "-",
    "◦" => "-", "▪" => "-", "▫" => "-", "▸" => "-", "►" => "-", "▶" => "-",
    "●" => "-", "○" => "-", "■" => "-", "□" => "-", "◆" => "-", "◇" => "-", "⁃" => "-", "∙" => "-",
    "‐" => "-", "‑" => "-", "‒" => "-", "―" => "-", "−" => "-",
    "′" => "'", "″" => "\"", "‛" => "'", "‟" => "\"",
    " " => "\n", " " => "\n"
  }.freeze

  # Spaces 1252 lacks become a plain space.
  SPACES = /[  -   　]/
  COMBINING_MARKS = /\p{Mn}/

  # A Prawn document that sanitizes every string it is asked to draw or
  # measure, so a new `pdf.text` call cannot reintroduce the crash.
  module Document
    def text(string, options = {})
      super(PdfText.sanitize(string), options)
    end

    def formatted_text(array, options = {})
      super(PdfText.sanitize_fragments(array), options)
    end

    def text_box(string, options = {})
      super(PdfText.sanitize(string), options)
    end

    def formatted_text_box(array, options = {})
      super(PdfText.sanitize_fragments(array), options)
    end

    def draw_text(text, options)
      super(PdfText.sanitize(text), options)
    end

    def width_of(string, options = {})
      super(PdfText.sanitize(string), options)
    end

    def height_of(string, options = {})
      super(PdfText.sanitize(string), options)
    end
  end

  module_function

  def sanitize(value)
    string = value.to_s
    string = string.dup.force_encoding(Encoding::UTF_8) unless string.encoding == Encoding::UTF_8
    string = string.scrub("").unicode_normalize(:nfc)
    return string if encodable?(string)

    string.gsub(SPACES, " ").each_char.map { |char| replace(char) }.join
  end

  def sanitize_fragments(fragments)
    Array(fragments).map do |fragment|
      fragment.is_a?(Hash) && fragment.key?(:text) ? fragment.merge(text: sanitize(fragment[:text])) : fragment
    end
  end

  def replace(char)
    return char if encodable?(char)
    return REPLACEMENTS[char] if REPLACEMENTS.key?(char)

    # Compatibility forms (full-width Ｊ, ligatures ﬁ, Ⅳ, ①, ǅ) fold to plain
    # letters and digits; only reached for characters 1252 cannot draw.
    folded = char.unicode_normalize(:nfkc)
    return folded.each_char.map { |part| replace(part) }.join if folded != char

    transliterated = I18n.transliterate(char, locale: :en, replacement: "")
    return transliterated if transliterated.present? && encodable?(transliterated)

    stripped = char.unicode_normalize(:nfd).gsub(COMBINING_MARKS, "")
    stripped.present? && stripped != char && encodable?(stripped) ? stripped : ""
  end

  def encodable?(string)
    string.encode(ENCODING)
    true
  rescue EncodingError
    false
  end
end
