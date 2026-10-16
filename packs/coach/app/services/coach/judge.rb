module Coach
  # Picks the section to work on next and scores each one: Jev when JEV_API_KEY is set, Haiku otherwise.
  module Judge
    LEVELS = %w[missing weak ok strong].freeze
    NEXT_STEP = "Which CV section should the coach work on next? Pick the weakest section that matters most."

    module_function

    def next_step(draft, llm: Coach::Llm) = call(draft, llm:)["next_step"]

    def review(draft, llm: Coach::Llm) = call(draft, llm:)["scores"]

    # Returns { "next_step" => section, "scores" => { section => 0.0..1.0 } }.
    def call(draft, llm: Coach::Llm)
      text = sanitize(draft)
      return fallback(text, llm) unless llm.judge?

      judgment = llm.judge(text, questions:)
      result(judgment[:next_step].choice.to_s,
             Coach::Draft::SECTIONS.index_with { |s| judgment[s].score.to_f / (LEVELS.size - 1) })
    rescue RubyLLM::Error, Faraday::Error => e
      # Jev being down shouldn't fail the turn; Haiku answers the same questions.
      Sentry.capture_exception(e, tags: { pack: "coach" })
      fallback(text, llm)
    end

    # Only section text leaves the app: the header's values (name, email, phone, city, country) are dropped.
    def sanitize(draft)
      filled = Coach::Draft::HEADER.select { |key| draft[key].present? } # field names only, never values
      draft = draft.except(*Coach::Draft::HEADER)
      header = "## header\n#{filled.any? ? "filled in: #{filled.join(', ')}" : '(empty)'}"
      sections = (Coach::Draft::SECTIONS - [ "header" ]).map { |s| "## #{s}\n#{render(draft[s])}" }
      [ header, *sections ].join("\n\n")
    end

    def questions
      scores = Coach::Draft::SECTIONS.to_h do |s|
        [ s.to_sym, { type: :score, instructions: "How complete and strong is the #{s} section?", levels: LEVELS } ]
      end
      { next_step: { type: :choice, instructions: NEXT_STEP,
                     options: Coach::Draft::SECTIONS.index_with { |s| "Work on the #{s} section" } }, **scores }
    end

    def fallback(text, llm)
      parsed = llm.fast_chat
                  .with_instructions(<<~TEXT.squish)
                    #{NEXT_STEP} Then score every section from 0 (#{LEVELS.first}) to 1 (#{LEVELS.last}).
                  TEXT
                  .with_schema(schema)
                  .ask(text)
                  .parsed.to_h
      result(parsed["next_step"], Coach::Draft::SECTIONS.index_with { |s| parsed.dig("scores", s).to_f })
    end

    def schema
      sections = Coach::Draft::SECTIONS
      scores = { type: "object", properties: sections.index_with { { type: "number" } }, required: sections, additionalProperties: false }
      { name: "judgment", schema: { type: "object", properties: { next_step: { type: "string", enum: sections }, scores: },
                                    required: %w[next_step scores], additionalProperties: false } }
    end

    # Keeps next_step in SECTIONS and scores in 0..1 whatever the model returned.
    def result(next_step, scores)
      scores = scores.transform_values { |v| v.clamp(0.0, 1.0) }
      { "next_step" => next_step.presence_in(Coach::Draft::SECTIONS) || scores.min_by(&:last).first, "scores" => scores }
    end

    def render(value)
      text = value.is_a?(Array) ? value.map { |e| "- #{e.is_a?(Hash) ? e.values.flatten.join(' | ') : e}" }.join("\n") : value.to_s
      text.presence || "(empty)"
    end
  end
end
