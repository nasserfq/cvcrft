module JobApplications
  # Answers an apply form's extra questions from CV facts only. Anything the CV
  # does not say, and any legal or sensitive question, comes back nil.
  class Answerer
    class Invalid < StandardError; end

    MAX_QUESTIONS = 40
    MAX_LABEL = 300
    MAX_OPTIONS = 50
    MAX_VALUE = 2_000
    TYPES = %w[text textarea select radio checkbox number date url email tel].freeze
    CHOICE_TYPES = %w[select radio checkbox].freeze

    # Never answered by the AI: the user decides these themselves.
    SENSITIVE = Regexp.union(
      /visa|sponsor|work permit|right to work|authori[sz]ed to work|legally|criminal|convict|felony|disabilit|gender|\bsex\b|\brace\b|ethnic|religio|veteran|salary|compensation|expected pay|pay expectation|consent|\bagree|\bterms\b|privacy|pregnan|marital/i,
      /تأشير|كفال|إقام|اقامه|سوابق|جنائي|إعاق|اعاق|الجنس|الراتب|راتب|ديان|موافق|الشروط|الخصوصي|الحالة الاجتماعية/
    )

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You fill in a job application form for the candidate. Answer only from the CV facts and contact details given.
      If they do not say, the value is null. Never invent anything.
      For select and radio questions the value must be exactly one of the options. For checkbox questions it is an array of options.
      Questions about visas, sponsorship, work authorisation, criminal records, disability, gender, salary, or any consent or legal statement are always null.
      Reply JSON {"answers":[{"id":"...","value":"..." or ["..."] or null}]}.
    PROMPT

    attr_reader :application

    def initialize(application)
      @application = application
    end

    # questions: [{"id","label","type","options","required"}] => [{"id","value"}], one per question.
    def call(questions)
      questions = validate(questions)
      askable = questions.reject { |q| sensitive?(q) }
      values = askable.any? ? ask(askable) : {}

      questions.map do |q|
        value = sensitive?(q) ? nil : clean(q, values[q["id"]])
        { "id" => q["id"], "value" => value }
      end
    end

    def validate(questions)
      raise Invalid, "questions must be a list" unless questions.is_a?(Array)
      raise Invalid, "at most #{MAX_QUESTIONS} questions" if questions.size > MAX_QUESTIONS

      ids = []
      questions.map.with_index do |q, i|
        raise Invalid, "question #{i + 1} is not an object" unless q.is_a?(Hash)

        q = q.stringify_keys

        id = q["id"].to_s
        raise Invalid, "question #{i + 1} needs an id" if id.blank? || id.size > 100
        raise Invalid, "question ids must be unique" if ids.include?(id)

        label = q["label"].to_s.squish
        raise Invalid, "question #{id} label is too long" if label.size > MAX_LABEL

        type = q["type"].to_s.presence || "text"
        raise Invalid, "question #{id} has an unknown type" unless TYPES.include?(type)

        options = Array(q["options"]).map { |o| o.to_s.squish }
        raise Invalid, "question #{id} has too many options" if options.size > MAX_OPTIONS
        raise Invalid, "question #{id} has an option that is too long" if options.any? { |o| o.size > MAX_LABEL }

        ids << id
        { "id" => id, "label" => label, "type" => type, "options" => options, "required" => ActiveModel::Type::Boolean.new.cast(q["required"]) || false }
      end
    end

    private

    def sensitive?(question) = question["label"].match?(SENSITIVE)

    def ask(questions)
      AiUsage.bump!(application.user, :answers)
      message = AiModel.complete(system: SYSTEM_PROMPT, user: prompt(questions), temperature: 0.1, max_tokens: 1_500)
      rows = JSON.parse(AiModel.json_body(message.content))["answers"]
      Array(rows).each_with_object({}) { |row, h| h[row["id"].to_s] = row["value"] if row.is_a?(Hash) }
    rescue StandardError => e
      Rails.logger.error("[auto_apply] answers failed for application #{application.id}: #{e.class}: #{e.message}")
      {}
    end

    def prompt(questions)
      posting = application.posting
      facts = CvFacts.new(application.user, resume_id, preference: Preference.find_by(user: application.user)).to_prompt(contact: true)
      "CV facts:\n#{facts}\n\nJob: #{posting.title} at #{posting.employer.name}, #{posting.location}\n\n" \
        "Questions:\n#{questions.map { |q| q.except('required') }.to_json}"
    end

    def resume_id = application.resume_id || ResumeBuilder::PublicApi.latest_complete(application.user)&.fetch("id")

    # Enforces the options rule in Ruby, whatever the model sent.
    def clean(question, value)
      return nil if value.nil?

      options = question["options"]
      case question["type"]
      when "checkbox"
        picked = Array(value).map(&:to_s) & options
        picked.presence
      when "select", "radio"
        value.is_a?(String) && options.include?(value) ? value : nil
      else
        return nil unless value.is_a?(String) || value.is_a?(Numeric)

        value.to_s.strip.first(MAX_VALUE).presence
      end
    end
  end
end
