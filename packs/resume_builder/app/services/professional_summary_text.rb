module ProfessionalSummaryText
  module_function

  def normalize(text)
    return if text.blank?

    value = text.to_s.strip
    value = extract_from_markdown_fence(value) || value
    extract_from_json_object(value) || value
  end

  def extract_from_markdown_fence(text)
    match = text.match(/\A```(?:json)?\s*(.*?)\s*```\z/m)
    match&.[](1)&.strip
  end

  def extract_from_json_object(text)
    return unless text.start_with?("{", "[")

    parsed = JSON.parse(text)
    case parsed
    when Hash
      parsed["english_text"].presence ||
        parsed["professional_summary"].presence ||
        parsed["summary"].presence
    else
      nil
    end
  rescue JSON::ParserError
    nil
  end
end
