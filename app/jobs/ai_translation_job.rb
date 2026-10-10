class AiTranslationJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  class OpenAIRequestError < StandardError
    attr_reader :status_code, :response_body, :request_id

    def initialize(message, status_code: nil, response_body: nil, request_id: nil)
      super(message)
      @status_code = status_code
      @response_body = response_body
      @request_id = request_id
    end

    def retryable?
      return true if status_code.nil?
      return true if [ 408, 409, 425, 429 ].include?(status_code)

      status_code >= 500
    end
  end

  def perform(arabic_text, user_id, resume_id = nil, options = {})
    @arabic_text = arabic_text
    @user_id = user_id
    @resume_id = resume_id
    # Convert string keys to symbol keys for internal use
    @options = options.transform_keys(&:to_sym)

    # Create AI translation record
    @translation = create_translation_record

    begin
      # Process the translation using Azure OpenAI
      result = call_azure_openai_api

      # Update the translation record with success
      update_translation_success(result)

      # Update resume if provided
      update_resume_with_translation(result) if @resume_id

      # Extract and create skills if requested
      create_skills_from_translation(result[:skills_extracted]) if result[:skills_extracted]

    rescue OpenAIRequestError => e
      if e.retryable?
        mark_translation_retryable(e)
        raise
      end

      handle_translation_error(e)
    rescue => e
      # Handle errors
      handle_translation_error(e)
      raise e
    end
  end

  private

  def create_translation_record
    user = User.find(@user_id)
    user.ai_translations.create!(
      arabic_text: @arabic_text,
      resume_id: @resume_id,
      ai_model: "gpt-4.1-mini",
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
                                temperature: (@options[:temperature] || 0.7).to_f, max_tokens: (@options[:max_tokens] || 500).to_i)

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
o     1. When given 3 descriptive sentences OR at least 50 words in Arabic about work experience, skills, or professional background, generate a comprehensive professional summary in English that incorporates all the information
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
          skills_extracted: parsed_content["skills_extracted"] || [],
          translation_notes: parsed_content["translation_notes"],
          tokens_used: AiModel.token_count(response),
          raw_response: content
        }
      else
        # Professional summary format
        {
          english_text: ProfessionalSummaryText.normalize(parsed_content["english_text"]),
          skills_extracted: parsed_content["skills_extracted"] || [],
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

  def update_translation_success(result)
    @translation.update!(
      english_text: result[:english_text],
      translation_quality: calculate_quality_score(result),
      tokens_used: result[:tokens_used],
      status: "completed",
      metadata: @translation.metadata.merge({
        skills_extracted: result[:skills_extracted],
        translation_notes: result[:translation_notes],
        raw_response: result[:raw_response]
      })
    )
  end

  def update_resume_with_translation(result)
    return unless @resume_id

    # Skip resume update for job descriptions translations - they don't update the resume directly
    return if @options[:job_descriptions]

    resume = Resume.find(@resume_id)

    # Only update professional summary for professional summary translations
    if @options[:professional_summary] && result[:english_text].present?
      # Truncate to 1000 characters if needed
      english_text = ProfessionalSummaryText.normalize(result[:english_text]).to_s[0, 1000]
      resume.update!(
        professional_summary_english: english_text,
        summary: english_text
      )
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

  def create_skills_from_translation(skills_data)
    return unless @resume_id && skills_data.present?

    resume = Resume.find(@resume_id)

    skills_data.each do |skill_data|
      # Skip if skill name is blank
      next if skill_data[:name].blank?

      # Check if skill already exists (check both name and skill_names)
      existing_skill = resume.skills.find_by(name: skill_data[:name]) ||
                      resume.skills.find_by(skill_names: [ skill_data[:name] ])

      unless existing_skill
        resume.skills.create!(
          name: skill_data[:name], # Keep legacy field for backward compatibility
          skill_names: [ skill_data[:name] ], # New field structure
          level: skill_data[:level] || "intermediate",
          category: skill_data[:category] || "technical"
        )
      end
    end
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
      english_text: "Translation failed: #{error.message}",
      metadata: @translation.metadata.merge({
        error: error.message,
        backtrace: error.backtrace.first(5)
      })
    )

    # Log the error
    Rails.logger.error "AI Translation failed for user #{@user_id}, jid=#{jid}: #{error.message}"
    if error.respond_to?(:status_code)
      Rails.logger.error "OpenAI status=#{error.status_code} request_id=#{error.request_id}"
    end
    Rails.logger.error error.backtrace.join("\n")
  end

  def mark_translation_retryable(error)
    @translation.update!(
      status: "processing",
      metadata: @translation.metadata.merge({
        retryable_error: true,
        last_error: error.message,
        provider_status: error.status_code,
        request_id: error.request_id
      }.compact)
    )

    Rails.logger.warn(
      "AI Translation transient failure for user #{@user_id}, jid=#{jid}, " \
      "status=#{error.status_code || 'n/a'}, request_id=#{error.request_id || 'n/a'}"
    )
  end
end
