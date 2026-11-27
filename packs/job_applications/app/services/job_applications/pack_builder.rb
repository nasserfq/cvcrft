module JobApplications
  # Builds an application's apply pack before any browser starts:
  #   1. the form's questions, read over HTTP by the submitter (none for email and manual);
  #   2. the tailored summary and the CV PDF with only that summary swapped (stored as cv_pdf);
  #   3. answers: ProfileAnswers first, then the profile's saved answers by label,
  #      then one Answerer AI call over what is left and safe to ask;
  #   4. one apply pack counted in AiUsage.
  # Returns {questions:, answers:, missing:, summary:, cover_letter:} for finish_pack!.
  class PackBuilder
    class NoResume < StandardError; end

    QUESTION_TYPES = %w[text textarea select radio checkbox file email tel url number].freeze

    attr_reader :application, :user, :posting

    def initialize(application)
      @application = application
      @user = application.user
      @posting = application.posting
    end

    def call
      questions = read_questions
      summary = TailoredSummary.new(user, resume_id, posting, cv_facts:).call
      store_pdf(summary)
      answers, missing, cover_letter = answer(questions)
      AiUsage.bump!(user, :packs)
      { questions:, answers:, missing:, summary:, cover_letter: }
    end

    private

    def resume_id
      @resume_id ||= ResumeBuilder::PublicApi.latest_complete(user)&.fetch("id") ||
        raise(NoResume, "user #{user.id} has no finished resume")
    end

    def cv_facts = @cv_facts ||= CvFacts.new(user, resume_id)
    def profile = @profile ||= Profile.find_by!(user:)

    def read_questions
      return [] unless application.channel == "browser"

      Array(Submitters.for(application)&.questions(posting)).map { |q| normalize(q) }
    end

    def normalize(question)
      q = question.to_h.stringify_keys
      { "id" => q["id"].to_s, "label" => q["label"].to_s.squish, "type" => QUESTION_TYPES.include?(q["type"].to_s) ? q["type"].to_s : "text",
        "options" => Array(q["options"]).map { |o| o.to_s.squish }, "required" => ActiveModel::Type::Boolean.new.cast(q["required"]) || false,
        "section" => q["section"].to_s == "eeo" ? "eeo" : "main" }
    end

    def store_pdf(summary)
      pdf = ResumeBuilder::PublicApi.pdf(user, resume_id, professional_summary: summary)
      Document.store!(application, kind: "cv_pdf", data: pdf["data"], content_type: "application/pdf",
                                   filename: pdf["filename"].presence || "cv.pdf")
    end

    # [answers, missing, cover_letter]
    def answer(questions)
      answers = {}
      blocked = []
      remaining = []
      cover_letter = nil

      questions.each do |q|
        if ProfileAnswers.cover_letter?(q) && !Sensitive.match?(q["label"])
          next unless q["required"]

          cover_letter ||= CoverLetter.new(application, facts: cv_facts.to_prompt).call
          if cover_letter then answers[q["id"]] = cover_letter
          else blocked << q
          end
          next
        end

        value = ProfileAnswers.match(q, profile:, contact: cv_facts.cv)
        value = saved(q) || value if value.nil? || value == :sensitive
        case value
        when nil then remaining << q
        when :sensitive then blocked << q
        else answers[q["id"]] = value
        end
      end

      result = Answerer.new(application, profile:, facts: cv_facts.to_prompt).call(remaining)
      missing = blocked.select { |q| q["required"] }.map { |q| q["id"] } + result[:missing]
      [ answers.merge(result[:answers]), missing, cover_letter ]
    end

    # The profile answers a question by its label once the user has answered
    # it on an earlier form (Application#answer! remembers non-sensitive ones).
    def saved(question)
      return nil unless rememberable?(question)

      Answerer.clean(question, profile.saved_answer(question["label"]))
    end

    def rememberable?(question)
      question["type"] != "file" && question["section"] != "eeo" && !Sensitive.match?(question["label"])
    end
  end
end
