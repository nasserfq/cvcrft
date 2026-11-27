module JobApplications
  # A short English cover letter for one application, written from CV facts
  # only. PackBuilder asks for one only when the form requires it.
  class CoverLetter
    MAX_CHARS = 5_000
    DESCRIPTION_CHARS = 3_000

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You write a cover letter of 150-250 words for the candidate, for the job given.
      Use only the CV facts given. Never invent employers, degrees, dates, numbers or skills.
      Plain text only: no placeholders, no address block, no subject line, no sign-off name.
      Write in English.
    PROMPT

    attr_reader :application, :facts

    # facts: CvFacts#to_prompt.
    def initialize(application, facts:)
      @application = application
      @facts = facts
    end

    # The letter, or nil when the AI fails. An open breaker raises so PrepareJob retries.
    def call
      posting = application.posting
      message = AiModel.complete(
        system: SYSTEM_PROMPT,
        user: "CV facts:\n#{facts}\n\nJob: #{posting.title} at #{posting.employer.name}, #{posting.location}\n" \
              "#{posting.description.to_s.first(DESCRIPTION_CHARS)}",
        temperature: 0.4, max_tokens: 700
      )
      message.content.to_s.strip.first(MAX_CHARS).presence
    rescue AiCircuit::OpenError
      raise
    rescue StandardError => e
      Rails.logger.error("[seera_apply] cover letter failed for application #{application.id}: #{e.class}: #{e.message}")
      nil
    end
  end
end
