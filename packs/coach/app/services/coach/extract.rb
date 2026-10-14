module Coach
  # Turns an uploaded CV's text into a draft in one cheap structured call.
  module Extract
    MODEL = ENV.fetch("COACH_FAST_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0")
    INSTRUCTIONS = <<~TEXT.squish
      Copy the CV below into the schema. Keep the CV's own language and wording, use YYYY-MM for dates,
      put each responsibility in its own string, and leave out anything the CV does not say.
    TEXT

    module_function

    def call(text)
      parsed = RubyLLM.chat(model: MODEL, provider: :bedrock)
                      .with_instructions(INSTRUCTIONS)
                      .with_schema(Coach::Draft.json_schema)
                      .ask(text.first(LinkedinPdfParserService::MAX_TEXT_CHARS))
                      .parsed
      # The model's output gets the same checks as save_section; invalid entries are dropped.
      Coach::Draft.clean(parsed)
    end
  end
end
