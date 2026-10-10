class CvImportJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  def perform(cv_import_id)
    @import = CvImport.find(cv_import_id)
    @import.mark_processing!

    begin
      # Parse the extracted text using Azure OpenAI
      result = call_azure_openai_api(@import.extracted_text)

      # Update the import with parsed data
      @import.mark_completed!(result)

      Rails.logger.info "[CvImport] Successfully parsed import #{cv_import_id}"
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
      You are an expert resume/CV parser. Your task is to extract structured resume data from uploaded CV/resume PDF text.

      CRITICAL REQUIREMENTS:
      1. Extract ONLY English text - REMOVE all Arabic characters and text completely
      2. Clean up any formatting issues, garbled text, or PDF artifacts
      3. Structure the data according to the JSON format below
      4. If a field is not found, leave it as empty string or empty array
      5. For work experiences, extract job title, company name, dates, and responsibilities as bullet points
      6. For education, extract degree, institution, and dates
      7. For skills, group them into logical categories (Technical, Languages, Soft Skills, Tools, etc.)
      8. Generate a professional summary if not explicitly present based on the CV content
      9. For certifications: include them even if only name is found (leave other fields empty)
      10. DO NOT include empty entries (no empty names, titles, or categories)
      11. Normalize dates to YYYY-MM format where possible. Use "Present" or leave end_date empty for current positions
      12. For languages section, extract spoken/written languages and proficiency levels

      Return ONLY valid JSON in this exact format:
      {
        "complete_name": "Full Name",
        "email": "email@example.com",
        "phone_number": "+1234567890",
        "city": "City",
        "country": "Country",
        "professional_summary": "Professional summary paragraph in English...",
        "work_experiences": [
          {
            "job_title": "Job Title",
            "company": "Company Name",
            "start_date": "2020-01",
            "end_date": "2023-12",
            "is_current": false,
            "responsibilities": [
              "Key responsibility or achievement 1",
              "Key responsibility or achievement 2"
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
            "category": "Tools & Technologies",
            "skill_names": ["Git", "Docker", "AWS"]
          },
          {
            "category": "Soft Skills",
            "skill_names": ["Leadership", "Communication"]
          }
        ],
        "certifications": [
          {
            "name": "Certification Name",
            "organization": "Issuing Organization",
            "date": "2023-06"
          }
        ],
        "languages": [
          {
            "language": "English",
            "proficiency": "Native"
          },
          {
            "language": "Arabic",
            "proficiency": "Fluent"
          }
        ]
      }
    PROMPT
  end

  def build_user_prompt(extracted_text)
    <<~PROMPT
      Parse the following CV/Resume PDF text and extract structured data.
      Remove ALL Arabic text and characters. Return ONLY clean English content.
      If the CV appears to be in Arabic, extract any English portions or translate key information.

      CV/Resume PDF Content:
      ---
      #{extracted_text}
      ---

      Return the structured JSON data as specified. Be thorough in extracting all available information.
    PROMPT
  end


  def parse_openai_response(response)
    # The model returns the text directly now; the envelope checks that used
    # to guard choices/message/content collapse into one emptiness check.
    content = response.content
    raise "AI response was empty" if content.nil? || content.empty?

    # Try to extract JSON from the response
    # Sometimes the model wraps it in ```json ... ```
    json_match = content.match(/```json\s*(.*?)\s*```/m)
    json_content = json_match ? json_match[1] : content

    begin
      parsed = JSON.parse(json_content)

      # Validate and normalize fields
      {
        "complete_name" => parsed["complete_name"] || "",
        "email" => parsed["email"] || "",
        "phone_number" => parsed["phone_number"] || "",
        "city" => parsed["city"] || "",
        "country" => parsed["country"] || "",
        "professional_summary" => parsed["professional_summary"] || "",
        "work_experiences" => normalize_work_experiences(parsed["work_experiences"] || []),
        "educations" => normalize_educations(parsed["educations"] || []),
        "skills" => normalize_skills(parsed["skills"] || []),
        "certifications" => normalize_certifications(parsed["certifications"] || []),
        "languages" => normalize_languages(parsed["languages"] || [])
      }
    rescue JSON::ParserError => e
      raise "Failed to parse AI response as JSON: #{e.message}"
    end
  end

  def normalize_work_experiences(experiences)
    experiences.map do |exp|
      next nil if exp["job_title"].blank? && exp["company"].blank?

      {
        "job_title" => exp["job_title"] || "",
        "company" => exp["company"] || "",
        "start_date" => exp["start_date"] || "",
        "end_date" => exp["is_current"] ? "" : (exp["end_date"] || ""),
        "is_current" => exp["is_current"] || false,
        "responsibilities" => Array(exp["responsibilities"]).reject(&:blank?)
      }
    end.compact
  end

  def normalize_educations(educations)
    educations.map do |edu|
      next nil if edu["degree"].blank? && edu["institution"].blank?

      {
        "degree" => edu["degree"] || "",
        "institution" => edu["institution"] || "",
        "start_date" => edu["start_date"] || "",
        "end_date" => edu["end_date"] || "",
        "gpa" => edu["gpa"] || "",
        "is_current" => edu["is_current"] || false
      }
    end.compact
  end

  def normalize_skills(skills)
    skills.map do |skill|
      skill_names = Array(skill["skill_names"]).reject(&:blank?)
      next nil if skill["category"].blank? || skill_names.empty?

      {
        "category" => skill["category"],
        "skill_names" => skill_names
      }
    end.compact
  end

  def normalize_certifications(certifications)
    certifications.map do |cert|
      next nil if cert["name"].blank?

      {
        "name" => cert["name"] || "",
        "organization" => cert["organization"] || "",
        "date" => cert["date"] || ""
      }
    end.compact
  end

  def normalize_languages(languages)
    languages.map do |lang|
      next nil if lang["language"].blank?

      {
        "language" => lang["language"] || "",
        "proficiency" => lang["proficiency"] || ""
      }
    end.compact
  end

  def handle_error(error)
    @import.mark_failed!(error.message)
    Rails.logger.error "[CvImport] Failed to parse import #{@import.id}: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
  end
end
