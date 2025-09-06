class AiTranslationJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

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
    # Get Azure OpenAI API key from environment or credentials
    api_key = Rails.application.credentials.azure[:openai_api_key] || ENV["AZURE_OPENAI_API_KEY"]

    # Prepare the prompt for translation
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt

    # Make the API call
    response = make_openai_request(api_key, system_prompt, user_prompt)

    # Parse and return the result
    parse_openai_response(response)
  end



    def make_openai_request(api_key, system_prompt, user_prompt)
    uri = URI("https://craftcv.openai.azure.com/openai/deployments/gpt-4.1-mini/chat/completions?api-version=2025-01-01-preview")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["api-key"] = api_key

    payload = {
      messages: [
        {
          role: "system",
          content: [
            {
              type: "text",
              text: system_prompt
            }
          ]
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: user_prompt
            }
          ]
        }
      ],
      temperature: @options["temperature"] || 0.7,
      top_p: @options["top_p"] || 0.95,
      max_tokens: @options["max_tokens"] || 13107
    }

    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == "200"
      JSON.parse(response.body)
    else
      raise "OpenAI API request failed: #{response.code} - #{response.body}"
    end
  end

  def build_system_prompt
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

  def build_user_prompt
    <<~PROMPT
      Please process the following Arabic text (either 3 descriptive sentences OR at least 50 words) about work experience, skills, or professional background:

      "#{@arabic_text}"

      Generate a comprehensive professional summary in English that incorporates all the information from this Arabic input. Focus on creating a cohesive, well-structured summary that highlights relevant skills and maintains professional terminology suitable for international job applications.
    PROMPT
  end

  def parse_openai_response(response)
    content = response["choices"][0]["message"]["content"]

    begin
      # Try to parse as JSON first
      parsed_content = JSON.parse(content)

      {
        english_text: parsed_content["english_text"],
        skills_extracted: parsed_content["skills_extracted"] || [],
        translation_notes: parsed_content["translation_notes"],
        tokens_used: response["usage"]["total_tokens"],
        raw_response: content
      }
    rescue JSON::ParserError
      # If not JSON, treat as plain text
      {
        english_text: content,
        skills_extracted: [],
        translation_notes: "Response was not in expected JSON format",
        tokens_used: response["usage"]["total_tokens"],
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

    resume = Resume.find(@resume_id)

    # Update work experience if this is a work experience translation
    if @options["work_experience_id"]
      work_exp = resume.work_experiences.find(@options["work_experience_id"])
      work_exp.update!(
        english_description: result[:english_text],
        ats_keywords: result[:skills_extracted].map { |s| s[:name] }
      )
    end

    # Update professional summary if this is a summary translation
    if @options["professional_summary"]
      resume.update!(
        professional_summary: result[:english_text],
        summary: result[:english_text] # Also update the main summary field
      )
    end
  end

  def create_skills_from_translation(skills_data)
    return unless @resume_id && skills_data.present?

    resume = Resume.find(@resume_id)

    skills_data.each do |skill_data|
      # Check if skill already exists
      existing_skill = resume.skills.find_by(name: skill_data[:name])

      unless existing_skill
        resume.skills.create!(
          name: skill_data[:name],
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
    Rails.logger.error "AI Translation failed for user #{@user_id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
  end
end
