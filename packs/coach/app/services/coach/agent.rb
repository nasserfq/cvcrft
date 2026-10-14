module Coach
  class Agent
    MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")
    TOOLS = [ Coach::Tools::SaveSection, Coach::Tools::ProposeRewrite, Coach::Tools::NextStep, Coach::Tools::ReviewCv,
              Coach::Tools::AskFields ].freeze

    PATH_PROMPTS = {
      "scratch" => <<~TEXT,
        The user is building a CV from scratch. The chat opened by asking for their first and last name. Work on one section at a time, in this order:
        header (contact details), work experience, education, skills, certifications, languages,
        and finally the professional summary. Ask short, specific questions, then turn the answers
        into strong, results-focused CV content and show it to the user. Once they confirm it,
        call save_section for that section before moving on. If save_section returns an error,
        fix the arguments or ask the user for the missing detail.
      TEXT
      "import" => <<~TEXT
        The user wants to improve an existing CV, which is already in the draft below.
        First, without calling any tool, summarise what you read (role, employers, education,
        skills) and ask the user to correct anything wrong; fix confirmed corrections with save_section.
        Then improve the professional summary and each job's responsibilities with propose_rewrite,
        one proposal at a time: say briefly why it is stronger and wait for the user to accept or
        reject it before the next one. Keep every fact from the original.
      TEXT
    }.freeze

    def initialize(chat)
      @chat = chat
      @tools = TOOLS.map { |tool| tool.new(@chat) }
    end

    # Box labels the reply asked for through ask_fields.
    def fields = @tools.grep(Coach::Tools::AskFields).first.labels

    # Rebuilt from the saved text every turn; the draft column holds the state.
    def reply(&on_text)
      # A scratch chat opens with our own question; the model's history must start with the user.
      *history, last = @chat.messages.order(:id).to_a.drop_while { |m| m.role == "assistant" }
      raise ArgumentError, "the last message must be the user's" unless last&.role == "user"

      llm = RubyLLM.chat(model: MODEL, provider: :bedrock)
                   .with_instructions(instructions)
                   .with_tools(*@tools)
      history.each { |m| llm.add_message(role: m.role.to_sym, content: m.content) }
      llm.ask(last.content) { |chunk| on_text.call(chunk.content) if chunk.content.present? }.content
    end

    def instructions
      <<~TEXT
        You are Seera's CV coach. Reply in the language the user writes in (Arabic or English).
        Keep replies short and friendly, and ask one question at a time. Write plain text: no Markdown, no **.
        Never invent facts the user did not give you: no job titles, employers, dates, numbers or
        qualifications of your own. If something is missing, ask for it.
        Call save_section after each section the user confirms.
        Call next_step when you are unsure what to ask next, and review_cv before you finish.
        Lead the conversation: always end your reply with the next question. When the answer is
        short facts (name, email, phone, city, dates, job title, company), call ask_fields with one
        label per fact so the user gets input boxes.

        #{PATH_PROMPTS.fetch(@chat.path)}
        Current draft (JSON): #{@chat.draft.to_json}
      TEXT
    end
  end
end
