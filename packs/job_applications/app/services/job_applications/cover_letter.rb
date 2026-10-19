module JobApplications
  # A short cover letter for one application, written once from CV facts only.
  module CoverLetter
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You write a cover letter of 150-250 words for the candidate, for the job given.
      Use only the CV facts given. Never invent employers, degrees, dates, numbers or skills.
      Plain text only: no placeholders, no address block, no subject line.
      Write in %<language>s.
    PROMPT

    module_function

    # The stored letter, or a new one; nil when the AI fails or the daily limit is reached.
    def for(application)
      return application.cover_letter if application.cover_letter.present?
      return nil if AiUsage.remaining(application.user, :answers, DAILY_ANSWER_LIMIT).zero?

      posting = application.posting
      AiUsage.bump!(application.user, :answers)
      language = arabic?("#{posting.title} #{posting.description}") ? "Arabic" : "English"
      message = AiModel.complete(
        system: format(SYSTEM_PROMPT, language:),
        user: "CV facts:\n#{facts(application)}\n\nJob: #{posting.title} at #{posting.employer.name}, #{posting.location}\n#{posting.description.to_s.first(3_000)}",
        temperature: 0.4, max_tokens: 700
      )
      text = message.content.to_s.strip.first(5_000).presence
      application.update!(cover_letter: text) if text
      text
    rescue StandardError => e
      Rails.logger.error("[auto_apply] cover letter failed for application #{application.id}: #{e.class}: #{e.message}")
      nil
    end

    def facts(application)
      resume_id = application.resume_id || ResumeBuilder::PublicApi.latest_complete(application.user)&.fetch("id")
      CvFacts.new(application.user, resume_id).to_prompt(contact: true)
    end

    def arabic?(text) = text.to_s.match?(/[؀-ۿ]/)
  end
end
