class LinkedinImportJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  def perform(linkedin_import_id)
    @import = LinkedinImport.find(linkedin_import_id)
    @import.mark_processing!

    begin
      # Parse the extracted text using Azure OpenAI
      result = call_azure_openai_api(@import.extracted_text)

      # Update the import with parsed data
      @import.mark_completed!(result)

      Rails.logger.info "[LinkedinImport] Successfully parsed import #{linkedin_import_id}"
    rescue => e
      handle_error(e)
      raise e
    end
  end

  private

  def call_azure_openai_api(extracted_text)
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(extracted_text)

    response = AiModel.complete(system: system_prompt, user: user_prompt,
                                temperature: 0.3, max_tokens: 8000)
    parse_openai_response(response)
  end

  def build_system_prompt
    <<~PROMPT
      You are an expert resume parser. Your task is to extract structured resume data from LinkedIn PDF text.

      CRITICAL REQUIREMENTS:
      1. Extract ONLY English text - REMOVE all Arabic characters and text completely
      2. Clean up any formatting issues or garbled text
      3. Structure the data according to the JSON format below
      4. If a field is not found, leave it as empty string or empty array
      5. For work experiences, extract job title, company name, dates, and responsibilities as bullet points
      6. For education, extract degree, institution, and graduation year
      7. For skills, group them into categories (Technical, Languages, Soft Skills, etc.)
      8. Generate a professional summary if not explicitly present
      9. For certifications: if only the name is available, still include it. Leave organization/date empty if not found.
      10. DO NOT include empty entries (no empty names, titles, or categories)

      Return ONLY valid JSON in this exact format:
      {
        "complete_name": "Full Name",
        "email": "email@example.com",
        "phone_number": "+1234567890",
        "city": "City",
        "country": "Country",
        "professional_summary": "Professional summary paragraph...",
        "work_experiences": [
          {
            "job_title": "Job Title",
            "company": "Company Name",
            "start_date": "2020-01",
            "end_date": "2023-12",
            "is_current": false,
            "responsibilities": [
              "Responsibility 1",
              "Responsibility 2"
            ]
          }
        ],
        "educations": [
          {
            "degree": "Bachelor of Science in Computer Science",
            "institution": "University Name",
            "start_date": "",
            "end_date": "2020",
            "gpa": "",
            "is_current": false
          }
        ],
        "skills": [
          {
            "category": "Technical Skills",
            "skill_names": ["JavaScript", "Python", "React"]
          },
          {
            "category": "Soft Skills",
            "skill_names": ["Leadership", "Communication"]
          }
        ],
        "certifications": [
          {
            "name": "Certification Name",
            "organization": "",
            "date": ""
          }
        ],
        "languages": [
          {
            "language": "English",
            "proficiency": "Native"
          }
        ]
      }
    PROMPT
  end

  def build_user_prompt(extracted_text)
    <<~PROMPT
      Parse the following LinkedIn PDF text and extract structured resume data.
      Remove ALL Arabic text and characters. Return ONLY clean English content.

      LinkedIn PDF Content:
      ---
      #{extracted_text}
      ---

      Return the structured JSON data as specified.
    PROMPT
  end


  def parse_openai_response(response)
    content = response.content

    json_content = AiModel.json_body(content)

    begin
      parsed = JSON.parse(json_content)

      # Validate required fields exist
      {
        "complete_name" => parsed["complete_name"] || "",
        "email" => parsed["email"] || "",
        "phone_number" => parsed["phone_number"] || "",
        "city" => parsed["city"] || "",
        "country" => parsed["country"] || "",
        "professional_summary" => parsed["professional_summary"] || "",
        "work_experiences" => parsed["work_experiences"] || [],
        "educations" => parsed["educations"] || [],
        "skills" => parsed["skills"] || [],
        "certifications" => parsed["certifications"] || [],
        "languages" => parsed["languages"] || []
      }
    rescue JSON::ParserError => e
      raise "Failed to parse AI response as JSON: #{e.message}"
    end
  end

  def handle_error(error)
    @import.mark_failed!(error.message)
    Rails.logger.error "[LinkedinImport] Failed to parse import #{@import.id}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
  end
end
