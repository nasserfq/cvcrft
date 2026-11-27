module JobApplications
  # The professional summary rewritten for one posting: one AI call over the
  # job and the CV facts (no name, email or phone). The rest of the CV never
  # goes through the AI; ResumeBuilder::PublicApi.pdf draws it as it is.
  # Falls back to the resume's own summary when the reply is blank or not English.
  class TailoredSummary
    MAX_CHARS = 1_200
    DESCRIPTION_CHARS = 3_000
    ARABIC = /[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]/

    # The summary rules of CvGenerator::PromptBuilder's base_requirements, copied.
    RULES = [
      "Make the professional summary concise and impactful (3-4 sentences)",
      "Include relevant keywords from the job description",
      "Emphasize achievements and skills that match the role",
      "Use strong action verbs and specific metrics",
      "Write the professional summary in English, even when the job description or the existing CV is in Arabic or another language"
    ].freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You rewrite the professional summary of a CV for one job. Use only the CV facts given.
      Never invent employers, degrees, dates, numbers or skills.
      #{RULES.map.with_index(1) { |rule, i| "#{i}. #{rule}" }.join("\n")}
      Reply with the summary text only: no heading, no quotes, no markdown.
    PROMPT

    attr_reader :user, :resume_id, :posting

    def initialize(user, resume_id, posting, cv_facts: nil)
      @user = user
      @resume_id = resume_id
      @posting = posting
      @cv_facts = cv_facts
    end

    # Raises AiCircuit::OpenError and other AI errors, so PrepareJob retries.
    def call
      message = AiModel.complete(system: SYSTEM_PROMPT, user: prompt, temperature: 0.4, max_tokens: 400)
      text = message.content.to_s.squish.delete_prefix('"').delete_suffix('"').first(MAX_CHARS)
      return fallback if text.blank? || text.match?(ARABIC)

      text
    end

    def prompt
      "Job: #{posting.title} at #{posting.employer.name}, #{posting.location}\n" \
        "#{posting.description.to_s.first(DESCRIPTION_CHARS)}\n\nCV facts:\n#{cv_facts.to_prompt}"
    end

    private

    def cv_facts = @cv_facts ||= CvFacts.new(user, resume_id)

    def fallback
      cv = cv_facts.cv
      cv["professional_summary_english"].presence || cv["professional_summary"].to_s
    end
  end
end
