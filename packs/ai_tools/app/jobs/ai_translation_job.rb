class AiTranslationJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  # Provider failures worth another try. Sidekiq retries the job; the
  # translation stays "processing" so the page keeps polling instead of
  # showing a failure the retry may fix.
  RETRYABLE_ERRORS = [
    RubyLLM::RateLimitError, RubyLLM::OverloadedError, RubyLLM::ServerError,
    RubyLLM::ServiceUnavailableError, Faraday::TimeoutError, Faraday::ConnectionFailed
  ].freeze

  # A job descriptions reply with no translated duties: nothing to give the
  # user, so the translation fails and the credit is given back.
  class EmptyTranslationError < StandardError; end

  # Retry soon: the page shows the result as soon as it is in.
  sidekiq_retry_in { |count| 5 * (count + 1) }

  sidekiq_retries_exhausted do |job, error|
    options = (job["args"][3] || {}).transform_keys(&:to_s)
    translation = find_translation(job["args"][1], options)
    if translation
      translation.fail_unfinished!(error.message, error_code: error_code_for(error))
    else
      refund_overage(job["args"][1], options)
    end
  end

  # The row the controller saved before queueing (translation_id); jobs
  # queued before it did are found by job_id.
  def self.find_translation(user_id, options)
    translations = AiTranslation.where(user_id: user_id)
    if options["translation_id"].present?
      translations.find_by(id: options["translation_id"])
    elsif options["job_id"].present?
      translations.where("metadata->>'job_id' = ?", options["job_id"].to_s).order(created_at: :desc).first
    end
  end

  # A translation that ran past the free allowance was paid with a credit
  # (Billing::UsageGate); a final failure gives it back. Safe to call twice.
  def self.refund_overage(user_id, options)
    kind = options["overage_kind"].presence
    user = kind && User.find_by(id: user_id)
    return unless user

    Billing::UsageGate.refund!(user, kind.to_sym, key: options["job_id"])
  end

  # A short, non-secret reason the page shows next to the failure message, so
  # a failure can be diagnosed without opening the admin panel.
  def self.error_code_for(error)
    message = error.message.to_s
    case error
    when RubyLLM::UnauthorizedError
      "ai_key_invalid"
    when RubyLLM::ForbiddenError
      message.match?(/security token|UnrecognizedClient|signature/i) ? "ai_key_invalid" : "ai_no_model_access"
    when *RETRYABLE_ERRORS
      "ai_unavailable"
    when RubyLLM::PaymentRequiredError
      "ai_billing"
    when RubyLLM::BadRequestError, RubyLLM::ContextLengthExceededError
      "ai_bad_request"
    when RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError
      "ai_config"
    when EmptyTranslationError
      "ai_empty_reply"
    else
      "internal"
    end
  end

  def perform(arabic_text, user_id, resume_id = nil, options = {})
    @arabic_text = arabic_text
    @user_id = user_id
    @resume_id = resume_id
    # Convert string keys to symbol keys for internal use
    @options = options.transform_keys(&:to_sym)

    @translation = find_or_create_translation_record
    return Rails.logger.warn("AI Translation #{@options[:translation_id]} is gone, jid=#{jid}") unless @translation

    # Pending until a worker picks it up. Conditional, so a row the sweeper
    # failed meanwhile stays failed.
    if @translation.pending?
      AiTranslation.where(id: @translation.id, status: "pending").update_all(status: "processing", updated_at: Time.current)
      @translation.reload
    end
    # A retry of a translation that already finished must not call the AI again.
    return if @translation.completed? || @translation.failed?

    begin
      result = call_azure_openai_api
      raise EmptyTranslationError, "No translated job descriptions in the reply" if @options[:job_descriptions] && !translated_jobs?(result)

      # The resume and its work experience are saved first, so the
      # translation is only completed once everything it changes is saved.
      ActiveRecord::Base.transaction do
        update_resume_with_translation(result) if @resume_id
        update_translation_success(result)
      end
    rescue *RETRYABLE_ERRORS => e
      mark_translation_retryable(e)
      raise
    rescue => e
      # Not worth retrying: the same request would fail the same way.
      handle_translation_error(e)
    end
  end

  private

  # The controller saves the row before queueing and passes its id. A job
  # queued before it did so has none, so one is made here (its retries then
  # find it by job_id). Nil when the saved row is gone.
  def find_or_create_translation_record
    existing = self.class.find_translation(@user_id, @options.transform_keys(&:to_s))
    return existing if existing || @options[:translation_id].present?

    User.find(@user_id).ai_translations.create!(
      arabic_text: @arabic_text,
      resume_id: @resume_id,
      ai_model: AiModel.default,
      status: "processing",
      metadata: @options
    )
  end

    def call_azure_openai_api
    # Prepare the prompt for translation
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt

    # Make the API call
    response = AiModel.complete(system: system_prompt, user: user_prompt,
                                temperature: (@options[:temperature] || 0.7).to_f, max_tokens: (@options[:max_tokens] || 500).to_i,
                                check: "Is the output an accurate, natural, professional English version of the CV text in the input, with nothing invented or left out?")

    # Parse and return the result
    parse_openai_response(response)
  end




  def build_system_prompt
    if @options[:job_descriptions]
      build_job_descriptions_system_prompt
    else
      build_professional_summary_system_prompt
    end
  end

  def build_professional_summary_system_prompt
    <<~PROMPT
      You are an AI assistant specialized in translating Arabic text to professional English for resumes and CVs.#{' '}
      Your task is to:
      1. When given 3 descriptive sentences OR at least 50 words in Arabic about work experience, skills, or professional background, generate a comprehensive professional summary in English that incorporates all the information
      2. Translate the Arabic content to English while maintaining professional tone and context
      3. Extract relevant skills and keywords for ATS systems from the content
      4. Ensure the generated summary is suitable for international job applications
      5. Create a cohesive, well-structured professional summary that flows naturally, regardless of whether the input is structured as sentences or descriptive words

      Return your response in JSON format with the following structure:
      {
        "english_text": "generated professional summary in English based on the Arabic input",
        "skills_extracted": [
          {"name": "skill name", "level": "beginner/intermediate/expert", "category": "technical/soft/domain"}
        ],
        "translation_notes": "notes about the translation and summary generation process"
      }
    PROMPT
  end

  def build_job_descriptions_system_prompt
    <<~PROMPT
      You are an AI assistant specialized in translating Arabic job descriptions to professional English for resumes and CVs.
      Your task is to:
      1. Translate EVERY piece of text from Arabic to professional English - even short phrases or single words
      2. Use action verbs and expand brief descriptions into full professional sentences
      3. If the input is a short phrase like "مدير مشروع" (Project Manager), expand it into a professional responsibility statement
      4. Maintain professional tone suitable for international job applications
      5. ALWAYS provide translations - never return empty arrays

      The input contains multiple jobs separated by "---". Each job has a header [Job Title - Company] followed by responsibilities.
      Even if the responsibility is just a job title or brief phrase, translate and expand it into a proper professional responsibility statement.

      Return your response in JSON format with the following structure:
      {
        "jobs": [
          {
            "job_title": "original job title",
            "company": "original company",
            "responsibilities_english": ["translated responsibility 1", "translated responsibility 2", ...]
          }
        ],
        "skills_extracted": [
          {"name": "skill name", "level": "beginner/intermediate/expert", "category": "technical/soft/domain"}
        ],
        "translation_notes": "notes about the translation process"
      }
    PROMPT
  end

  def build_user_prompt
    if @options[:job_descriptions]
      build_job_descriptions_user_prompt
    else
      build_professional_summary_user_prompt
    end
  end

  def build_professional_summary_user_prompt
    <<~PROMPT
      Please process the following Arabic text (either 3 descriptive sentences OR at least 50 words) about work experience, skills, or professional background:

      "#{@arabic_text}"

      Generate a comprehensive professional summary in English that incorporates all the information from this Arabic input. Focus on creating a cohesive, well-structured summary that highlights relevant skills and maintains professional terminology suitable for international job applications.
    PROMPT
  end

  def build_job_descriptions_user_prompt
    <<~PROMPT
      Please translate the following job descriptions from Arabic to professional English. Each job section is separated by "---":

      #{@arabic_text}

      IMPORTANT: Translate ALL text provided, even if it's just a short phrase or job title.#{' '}
      - If the responsibility is brief like "مدير مشروع تقني" (Technical Project Manager), expand it into a full professional statement like "Led and managed technical projects from conception to completion"
      - NEVER return empty responsibilities_english arrays
      - Each Arabic line should result in at least one English translation
      - Use action verbs and professional language suitable for international CVs
    PROMPT
  end

  def parse_openai_response(response)
    content = response.content
    content = ProfessionalSummaryText.extract_from_markdown_fence(content) || content.to_s.strip

    begin
      # Try to parse as JSON first
      parsed_content = JSON.parse(content)

      if @options[:job_descriptions]
        # Job descriptions format
        {
          jobs: parsed_content["jobs"] || [],
          english_text: parsed_content.to_json, # Store full response as english_text
          skills_extracted: normalize_skills(parsed_content["skills_extracted"]),
          translation_notes: parsed_content["translation_notes"],
          tokens_used: AiModel.token_count(response),
          raw_response: content
        }
      else
        # Professional summary format
        {
          english_text: ProfessionalSummaryText.normalize(parsed_content["english_text"]),
          skills_extracted: normalize_skills(parsed_content["skills_extracted"]),
          translation_notes: parsed_content["translation_notes"],
          tokens_used: AiModel.token_count(response),
          raw_response: content
        }
      end
    rescue JSON::ParserError
      # If not JSON, treat as plain text (also unwrap embedded JSON blobs)
      {
        english_text: ProfessionalSummaryText.normalize(content),
        skills_extracted: [],
        translation_notes: "Response was not in expected JSON format",
        tokens_used: AiModel.token_count(response),
        raw_response: content
      }
    end
  end

  # The AI's skills come back as JSON, so their keys are strings. Each one is
  # made readable by `skill[:name]` and `skill["name"]` alike; a bare string is
  # taken as the skill's name, and anything without a name is dropped.
  def normalize_skills(skills)
    Array(skills).filter_map do |skill|
      skill = { name: skill } if skill.is_a?(String)
      next unless skill.is_a?(Hash)

      skill = skill.with_indifferent_access
      skill if skill[:name].to_s.strip.present?
    end
  end

  def translated_jobs?(result)
    Array(result[:jobs]).any? do |job|
      job.is_a?(Hash) && Array(job["responsibilities_english"]).any? { |line| line.to_s.strip.present? }
    end
  end

  def update_translation_success(result)
    @translation.update!(
      english_text: result[:english_text],
      translation_quality: calculate_quality_score(result),
      tokens_used: result[:tokens_used],
      status: "completed",
      metadata: @translation.metadata.merge({
        skills_extracted: result[:skills_extracted],
        translation_notes: result[:translation_notes],
        raw_response: result[:raw_response],
        resume_updated_at: @resume_updated_at
      }.compact)
    )
  end

  def update_resume_with_translation(result)
    return unless @resume_id

    # Skip resume update for job descriptions translations - they don't update the resume directly
    return if @options[:job_descriptions]

    resume = Resume.find_by!(id: @resume_id, user_id: @user_id)

    # Only update professional summary for professional summary translations
    if @options[:professional_summary] && result[:english_text].present?
      # Truncate to 1000 characters if needed
      english_text = ProfessionalSummaryText.normalize(result[:english_text]).to_s[0, 1000]
      resume.assign_attributes(professional_summary_english: english_text, summary: english_text)
      save_translated_resume!(resume, :professional_summary_english, :summary)
      @resume_updated_at = resume.updated_at.iso8601(6)
    end

    # Update work experience if this is a work experience translation
    if @options[:work_experience_id]
      work_exp = resume.work_experiences.find(@options[:work_experience_id])
      work_exp.update!(
        english_description: result[:english_text],
        ats_keywords: result[:skills_extracted].map { |s| s[:name] }
      )
    end
  end

  # A finished resume is saved with full validation. A draft may still be
  # missing fields the builder asks for later (a name, an email), which must
  # not fail a paid translation: only the translated fields are checked, then
  # it is saved the way builder autosaves drafts (validate: false).
  def save_translated_resume!(resume, *fields)
    return resume.save! unless resume.draft?

    resume.valid?
    raise ActiveRecord::RecordInvalid, resume if fields.any? { |field| resume.errors[field].any? }

    resume.save!(validate: false)
  end

  def calculate_quality_score(result)
    # Simple quality scoring based on response completeness
    score = 0
    score += 50 if result[:english_text].present?
    score += 25 if result[:skills_extracted].present?
    score += 15 if result[:translation_notes].present?
    score += 10 if result[:raw_response].length > 100

    # Convert numeric score to allowed string values
    case score
    when 0..50
      "low"
    when 51..85
      "medium"
    else
      "high"
    end
  end

  def handle_translation_error(error)
    @translation.update!(
      status: "failed",
      english_text: "Translation failed: #{error.message}".truncate(5000),
      metadata: @translation.metadata.merge({
        error: error.message,
        error_code: self.class.error_code_for(error),
        backtrace: Array(error.backtrace).first(5)
      })
    )
    self.class.refund_overage(@user_id, @options.transform_keys(&:to_s))

    # Log the error
    Rails.logger.error "AI Translation failed for user #{@user_id}, jid=#{jid}: #{error.message}"
    Rails.logger.error Array(error.backtrace).join("\n")
  end

  def mark_translation_retryable(error)
    @translation.update!(
      status: "processing",
      metadata: @translation.metadata.merge({
        retryable_error: true,
        last_error: error.message,
        error_code: self.class.error_code_for(error)
      })
    )

    Rails.logger.warn "AI Translation transient failure for user #{@user_id}, jid=#{jid}: #{error.class}: #{error.message}"
  end
end
