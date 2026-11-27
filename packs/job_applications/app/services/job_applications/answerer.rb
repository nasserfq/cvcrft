module JobApplications
  # One AI call that answers an apply form's remaining questions from CV facts
  # and profile facts only. Sensitive, EEO, file and profile-owned questions
  # (visa, salary, contact details) are never sent. Ruby enforces the options,
  # whatever the model replies.
  #
  #   call(questions) -> {answers: {id => value}, missing: [id]}
  #
  # missing holds the required questions left unanswered; optional ones are left blank.
  class Answerer
    MAX_QUESTIONS = 40
    MAX_LABEL = 300
    MAX_OPTIONS = 50
    MAX_VALUE = 2_000
    TYPES = %w[text textarea select radio checkbox email tel url number].freeze
    CHOICE_TYPES = %w[select radio].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You fill in a job application form for the candidate. Answer only from the CV facts and candidate facts given.
      If they do not say, the value is null. Never invent anything.
      For select and radio questions the value must be exactly one of the options. For checkbox questions it is an array of options.
      Answer in English. Keep text answers short and factual.
      Questions about visas, sponsorship, salary, criminal records, disability, gender, or any consent or legal statement are always null.
      Reply JSON {"answers":[{"id":"...","value":"..." or ["..."] or null}]}.
    PROMPT

    attr_reader :application, :profile, :facts

    # facts: CvFacts#to_prompt (no name, email or phone).
    def initialize(application, profile:, facts:)
      @application = application
      @profile = profile
      @facts = facts
    end

    def call(questions)
      questions = Array(questions).map { |q| q.to_h.stringify_keys }
      askable = questions.select { |q| self.class.askable?(q) }.first(MAX_QUESTIONS)
      values = askable.any? ? ask(askable) : {}

      answers = {}
      missing = []
      questions.each do |q|
        value = askable.include?(q) ? self.class.clean(q, values[q["id"].to_s]) : nil
        if value.nil?
          missing << q["id"].to_s if q["required"]
        else
          answers[q["id"].to_s] = value
        end
      end
      { answers:, missing: }
    end

    # Only what the AI may see: no sensitive, EEO, file or profile-owned question.
    def self.askable?(question)
      TYPES.include?(question["type"].to_s) && question["section"] != "eeo" && question["id"].present? &&
        question["label"].to_s.size <= MAX_LABEL && Array(question["options"]).size <= MAX_OPTIONS &&
        !Sensitive.match?(question["label"]) && !ProfileAnswers.topic?(question)
    end

    # The value if it fits the question, else nil. Also cleans saved answers.
    def self.clean(question, value)
      return nil if value.nil?

      options = Array(question["options"]).map(&:to_s)
      case question["type"].to_s
      when "checkbox"
        return nil if options.empty?

        (Array(value).map(&:to_s) & options).presence
      when *CHOICE_TYPES
        value.is_a?(String) && options.include?(value) ? value : nil
      when "number"
        value.to_s.strip.match?(/\A\d+(\.\d+)?\z/) ? value.to_s.strip : nil
      else
        return nil unless value.is_a?(String) || value.is_a?(Numeric)

        value.to_s.strip.first(MAX_VALUE).presence
      end
    end

    private

    # An open breaker raises so PrepareJob retries; any other failure leaves
    # everything unanswered.
    def ask(questions)
      message = AiModel.complete(system: SYSTEM_PROMPT, user: prompt(questions), temperature: 0.1, max_tokens: 1_500)
      rows = JSON.parse(AiModel.json_body(message.content))["answers"]
      Array(rows).each_with_object({}) { |row, h| h[row["id"].to_s] = row["value"] if row.is_a?(Hash) }
    rescue AiCircuit::OpenError
      raise
    rescue StandardError => e
      Rails.logger.error("[seera_apply] answers failed for application #{application.id}: #{e.class}: #{e.message}")
      {}
    end

    def prompt(questions)
      posting = application.posting
      shown = questions.map { |q| { id: q["id"].to_s, label: q["label"].to_s, type: q["type"].to_s, options: Array(q["options"]) } }
      "CV facts:\n#{facts}\n\nCandidate facts:\n#{candidate_facts.to_json}\n\n" \
        "Job: #{posting.title} at #{posting.employer.name}, #{posting.location}\n\nQuestions:\n#{shown.to_json}"
    end

    def candidate_facts
      return {} unless profile

      { "nationality" => profile.nationality, "notice_period" => ProfileAnswers::NOTICE_TEXT[profile.notice_period] }.compact
    end
  end
end
