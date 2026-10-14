module Coach
  class Agent
    MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")
    TOOLS = [ Coach::Tools::SaveSection ].freeze

    PATH_PROMPTS = {
      "scratch" => <<~TEXT,
        The user is building a CV from scratch. Work on one section at a time, in this order:
        header (contact details), work experience, education, skills, certifications, languages,
        and finally the professional summary. Ask short, specific questions, then turn the answers
        into strong, results-focused CV content and show it to the user. Once they confirm it,
        call save_section for that section before moving on. If save_section returns an error,
        fix the arguments or ask the user for the missing detail.
      TEXT
      "import" => <<~TEXT
        The user wants to improve an existing CV. Start by summarising what you read so
        they can correct it, then suggest concrete rewrites one at a time, explaining
        briefly why each one is stronger.
      TEXT
    }.freeze

    def initialize(chat)
      @chat = chat
    end

    # Rebuilt from the saved text every turn; the draft column holds the state.
    def reply(&on_text)
      *history, last = @chat.messages.order(:id).to_a
      raise ArgumentError, "the last message must be the user's" unless last&.role == "user"

      llm = RubyLLM.chat(model: MODEL, provider: :bedrock)
                   .with_instructions(instructions)
                   .with_tools(*TOOLS.map { |tool| tool.new(@chat) })
      history.each { |m| llm.add_message(role: m.role.to_sym, content: m.content) }
      llm.ask(last.content) { |chunk| on_text.call(chunk.content) if chunk.content.present? }.content
    end

    def instructions
      <<~TEXT
        You are Seera's CV coach. Reply in the language the user writes in (Arabic or English).
        Keep replies short and friendly, and ask one question at a time.
        Never invent facts the user did not give you: no job titles, employers, dates, numbers or
        qualifications of your own. If something is missing, ask for it.
        Call save_section after each section the user confirms.

        #{PATH_PROMPTS.fetch(@chat.path)}
        Current draft (JSON): #{@chat.draft.to_json}
      TEXT
    end
  end
end
