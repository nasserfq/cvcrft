module Coach
  # Turns an uploaded CV's text into a draft in one cheap structured call.
  module Extract
    INSTRUCTIONS = <<~TEXT.squish
      Copy the CV below into the schema. Keep the CV's own language and wording, use YYYY-MM for dates,
      put each responsibility in its own string, and leave out anything the CV does not say.
    TEXT

    module_function

    def call(text, llm: Coach::Llm)
      parsed = llm.fast_chat
                  .with_instructions(INSTRUCTIONS)
                  .with_schema(Coach::Draft.json_schema)
                  .ask(text.first(LinkedinPdfParserService::MAX_TEXT_CHARS))
                  .parsed
      # The model's output gets the same checks as save_section; invalid entries are dropped.
      Coach::Draft.clean(parsed)
    end
  end
end
