module CvGenerator
  # The ATS PDF templates draw text in Helvetica, a built-in PDF font that only
  # covers Windows-1252, so any Arabic in the summary makes Prawn raise
  # IncompatibleStringEncoding and the whole generation fails. The prompt asks
  # for English, but with an Arabic job description the model sometimes
  # answers in Arabic anyway. This translates such a summary once.
  class EnglishSummary
    class NotEnglish < StandardError; end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You translate CV professional summaries into clear, professional English.
      Return only the translated summary as plain text: no quotes, no JSON, no notes.
    PROMPT

    def self.pdf_safe?(text)
      text.to_s.encode("windows-1252")
      true
    rescue EncodingError
      false
    end

    def initialize(llm: AiModel)
      @llm = llm
    end

    def call(summary)
      return summary if summary.blank? || self.class.pdf_safe?(summary)

      response = @llm.complete(system: SYSTEM_PROMPT, user: summary.to_s, temperature: 0.2, max_tokens: 1000)
      translated = response.content.to_s.strip
      raise NotEnglish, "Professional summary is not in English" unless translated.present? && self.class.pdf_safe?(translated)

      translated
    end
  end
end
