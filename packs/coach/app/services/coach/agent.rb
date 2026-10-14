module Coach
  class Agent
    MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")
    TOOLS = [].freeze

    PATH_PROMPTS = {
      "scratch" => <<~TEXT,
        The user is building a CV from scratch. Interview them one section at a time:
        contact details, professional summary, work experience, education, skills,
        certifications and languages. Ask short, specific questions and turn their
        answers into strong, results-focused CV content.
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

        #{PATH_PROMPTS.fetch(@chat.path)}
        Current draft (JSON): #{@chat.draft.to_json}
      TEXT
    end
  end
end
