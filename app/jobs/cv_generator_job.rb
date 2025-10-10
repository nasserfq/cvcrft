class CvGeneratorJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  def perform(job_description, user_id, resume_id = nil, options = {})
    Rails.logger.info "=== CV GENERATOR JOB STARTED ==="
    Rails.logger.info "Job Description: #{job_description.truncate(200)}"
    Rails.logger.info "User ID: #{user_id}"
    Rails.logger.info "Resume ID: #{resume_id}"
    Rails.logger.info "Options: #{options.inspect}"

    @job_description = job_description
    @user_id = user_id
    @resume_id = resume_id
    @options = options.transform_keys(&:to_sym)

    # Find existing CV generation record (created by service)
    Rails.logger.info "=== FINDING CV GENERATION RECORD ==="
    @cv_generation = find_cv_generation_record
    Rails.logger.info "CV Generation Record Found: ID #{@cv_generation.id}"

    begin
      # Get existing resume data if resume_id is provided
      if @resume_id
        Rails.logger.info "=== LOADING EXISTING RESUME ==="
        @existing_resume = Resume.find(@resume_id)
        Rails.logger.info "Existing Resume Found: ID #{@existing_resume.id}"
        Rails.logger.info "Existing Resume Name: #{@existing_resume.complete_name}"
        Rails.logger.info "Existing Work Experiences: #{@existing_resume.work_experiences.count}"
        Rails.logger.info "Existing Skills: #{@existing_resume.skills.count}"
      else
        Rails.logger.info "No existing resume provided - will create new resume"
      end

      # Process the CV generation using Azure OpenAI
      Rails.logger.info "=== CALLING AZURE OPENAI API ==="
      result = call_azure_openai_api
      Rails.logger.info "Azure OpenAI API Response Received"
      Rails.logger.info "Generated Professional Summary: #{result[:professional_summary].truncate(200)}"
      Rails.logger.info "Tokens Used: #{result[:tokens_used]}"

      # Update the CV generation record with success (but keep status as processing)
      Rails.logger.info "=== UPDATING CV GENERATION RECORD ==="
      update_cv_generation_success(result)
      Rails.logger.info "CV Generation Record Updated Successfully"

      # Create or update resume with generated content
      Rails.logger.info "=== CREATING/UPDATING RESUME ==="
      create_or_update_resume(result)
      Rails.logger.info "Resume Created/Updated Successfully"

      # Generate PDF after resume is updated
      Rails.logger.info "=== GENERATING PDF ==="
      generate_pdf_for_resume
      Rails.logger.info "PDF Generated Successfully"

      # Now mark as completed after PDF is generated
      Rails.logger.info "=== MARKING AS COMPLETED ==="
      @cv_generation.update!(status: "completed")
      Rails.logger.info "CV Generation marked as completed"

      Rails.logger.info "=== CV GENERATION COMPLETED SUCCESSFULLY ==="

    rescue => e
      # Handle errors
      Rails.logger.error "=== CV GENERATION FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      handle_cv_generation_error(e)
      raise e
    end
  end

  private

  def find_cv_generation_record
    # Find the most recent CV generation record for this user with matching job description
    user = User.find(@user_id)
    user.cv_generations
        .where(job_description: @job_description, status: "processing")
        .order(created_at: :desc)
        .first
  end

  def call_azure_openai_api
    Rails.logger.info "=== AZURE OPENAI API CALL STARTED ==="

    # Get Azure OpenAI API key from environment or credentials
    api_key = Rails.application.credentials.azure[:openai_api_key] || ENV["AZURE_OPENAI_API_KEY"]
    Rails.logger.info "API Key Present: #{api_key.present?}"

    # Prepare the prompt for CV generation
    Rails.logger.info "=== BUILDING PROMPTS ==="
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt

    Rails.logger.info "System Prompt Length: #{system_prompt.length} characters"
    Rails.logger.info "User Prompt Length: #{user_prompt.length} characters"
    Rails.logger.info "System Prompt Preview: #{system_prompt.truncate(200)}"
    Rails.logger.info "User Prompt Preview: #{user_prompt.truncate(200)}"

    # Make the API call
    Rails.logger.info "=== MAKING OPENAI REQUEST ==="
    response = make_openai_request(api_key, system_prompt, user_prompt)
    Rails.logger.info "OpenAI Request Completed Successfully"

    # Parse and return the result
    Rails.logger.info "=== PARSING OPENAI RESPONSE ==="
    result = parse_openai_response(response)
    Rails.logger.info "Response Parsed Successfully"
    Rails.logger.info "Generated Professional Summary: #{result[:professional_summary].truncate(200)}"
    Rails.logger.info "Tokens Used: #{result[:tokens_used]}"

    result
  end

  def make_openai_request(api_key, system_prompt, user_prompt)
    Rails.logger.info "=== MAKING OPENAI HTTP REQUEST ==="
    uri = URI("https://craftcv.openai.azure.com/openai/deployments/gpt-4.1-mini/chat/completions?api-version=2025-01-01-preview")
    Rails.logger.info "Request URI: #{uri}"

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
      temperature: (@options[:temperature] || 0.7).to_f,
      top_p: (@options[:top_p] || 0.95).to_f,
      max_tokens: (@options[:max_tokens] || 15000).to_i
    }

    Rails.logger.info "Request Payload:"
    Rails.logger.info "  Temperature: #{payload[:temperature]}"
    Rails.logger.info "  Top P: #{payload[:top_p]}"
    Rails.logger.info "  Max Tokens: #{payload[:max_tokens]}"
    Rails.logger.info "  Messages Count: #{payload[:messages].count}"

    request.body = payload.to_json
    Rails.logger.info "Request Body Length: #{request.body.length} characters"

    Rails.logger.info "=== SENDING HTTP REQUEST ==="
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    Rails.logger.info "HTTP Response Code: #{response.code}"
    Rails.logger.info "HTTP Response Body Length: #{response.body.length} characters"

    if response.code == "200"
      Rails.logger.info "OpenAI API Request Successful"
      JSON.parse(response.body)
    else
      Rails.logger.error "OpenAI API Request Failed"
      Rails.logger.error "Response Code: #{response.code}"
      Rails.logger.error "Response Body: #{response.body}"
      raise "OpenAI API request failed: #{response.code} - #{response.body}"
    end
  end

  def build_system_prompt
    <<~PROMPT
      You are an AI assistant specialized in generating professional summaries based on job descriptions and existing CV data.

      Your task is to:
      1. Analyze the provided job description to understand the requirements, skills, and qualifications needed
      2. Use the existing CV data (if provided) as a foundation to build upon
      3. Generate a compelling, ATS-optimized professional summary that matches the job requirements
      4. Highlight the most relevant skills, experiences, and achievements from the existing CV
      5. Use professional language and formatting suitable for international job applications
      6. Keep the summary concise (2-3 sentences) but impactful
      7. Ensure the summary is tailored specifically to the job description while drawing from the person's actual experience

      Return your response in JSON format with the following structure:
      {
        "professional_summary": "A compelling professional summary tailored to the job description"
      }
    PROMPT
  end

  def build_user_prompt
    existing_cv_data = ""

    if @existing_resume
      existing_cv_data = build_existing_cv_context
    end

    <<~PROMPT
      Please generate a professional summary based on the following job description:

      JOB DESCRIPTION:
      "#{@job_description}"

      #{existing_cv_data}

      Generate a compelling, ATS-optimized professional summary that matches the job requirements and highlights the most relevant qualifications and experiences from the existing CV data. Keep it concise (2-3 sentences) but impactful.
    PROMPT
  end

  def build_existing_cv_context
    Rails.logger.info "=== BUILDING EXISTING CV CONTEXT ==="

    return "" unless @existing_resume
    Rails.logger.info "Existing Resume Found: ID #{@existing_resume.id}"

    context = "\n\nEXISTING CV DATA TO BUILD UPON:\n"

    # Professional Summary
    if @existing_resume.professional_summary.present?
      context += "Professional Summary: #{@existing_resume.professional_summary}\n"
      Rails.logger.info "Added Professional Summary to context"
    else
      Rails.logger.info "No existing professional summary found"
    end

    # Work Experiences
    if @existing_resume.work_experiences.any?
      context += "\nWork Experiences:\n"
      Rails.logger.info "Found #{@existing_resume.work_experiences.count} work experiences"
      @existing_resume.work_experiences.each do |exp|
        context += "- #{exp.job_title} at #{exp.company} (#{exp.start_date} - #{exp.end_date || 'Present'})\n"
        if exp.responsibilities.present?
          # Handle responsibilities as either string or array
          responsibilities_text = if exp.responsibilities.is_a?(Array)
            exp.responsibilities.join(", ")
          else
            exp.responsibilities.to_s
          end
          context += "  Responsibilities: #{responsibilities_text}\n"
        end
      end
    else
      Rails.logger.info "No work experiences found"
    end

    # Skills
    if @existing_resume.skills.any?
      context += "\nSkills:\n"
      Rails.logger.info "Found #{@existing_resume.skills.count} skills"
      @existing_resume.skills.group_by(&:category).each do |category, skills|
        context += "- #{category.humanize}: #{skills.map(&:name).join(', ')}\n"
      end
    else
      Rails.logger.info "No skills found"
    end

    # Education
    if @existing_resume.educations.any?
      context += "\nEducation:\n"
      Rails.logger.info "Found #{@existing_resume.educations.count} education entries"
      @existing_resume.educations.each do |edu|
        context += "- #{edu.degree} from #{edu.institution} (#{edu.start_date} - #{edu.end_date})\n"
      end
    else
      Rails.logger.info "No education entries found"
    end

    # Certifications
    if @existing_resume.certifications.any?
      context += "\nCertifications:\n"
      Rails.logger.info "Found #{@existing_resume.certifications.count} certifications"
      @existing_resume.certifications.each do |cert|
        context += "- #{cert.name} from #{cert.organization} (#{cert.date})\n"
      end
    else
      Rails.logger.info "No certifications found"
    end

    # Languages
    if @existing_resume.languages.any?
      context += "\nLanguages:\n"
      Rails.logger.info "Found #{@existing_resume.languages.count} languages"
      @existing_resume.languages.each do |lang|
        context += "- #{lang.language} (#{lang.proficiency})\n"
      end
    else
      Rails.logger.info "No languages found"
    end

    Rails.logger.info "Context built successfully, length: #{context.length} characters"
    Rails.logger.info "Context preview: #{context.truncate(300)}"

    context
  end

  def parse_openai_response(response)
    Rails.logger.info "=== PARSING OPENAI RESPONSE ==="

    content = response["choices"][0]["message"]["content"]
    Rails.logger.info "Raw Response Content Length: #{content.length} characters"
    Rails.logger.info "Raw Response Content Preview: #{content.truncate(300)}"

    tokens_used = response["usage"]["total_tokens"]
    Rails.logger.info "Total Tokens Used: #{tokens_used}"

    begin
      # Try to parse as JSON first
      Rails.logger.info "=== ATTEMPTING JSON PARSING ==="
      parsed_content = JSON.parse(content)
      Rails.logger.info "JSON Parsing Successful"
      Rails.logger.info "Parsed Content Keys: #{parsed_content.keys}"

      result = {
        professional_summary: parsed_content["professional_summary"],
        work_experiences: parsed_content["work_experiences"] || [],
        skills: parsed_content["skills"] || [],
        educations: parsed_content["educations"] || [],
        certifications: parsed_content["certifications"] || [],
        languages: parsed_content["languages"] || [],
        ats_optimization_notes: parsed_content["ats_optimization_notes"],
        generation_notes: parsed_content["generation_notes"],
        tokens_used: tokens_used,
        raw_response: content
      }

      Rails.logger.info "Parsed Professional Summary: #{result[:professional_summary].truncate(200)}"
      Rails.logger.info "Work Experiences Count: #{result[:work_experiences].count}"
      Rails.logger.info "Skills Count: #{result[:skills].count}"

      result
    rescue JSON::ParserError => e
      # If not JSON, treat as plain text and create a basic structure
      Rails.logger.warn "=== JSON PARSING FAILED ==="
      Rails.logger.warn "JSON Parse Error: #{e.message}"
      Rails.logger.warn "Treating response as plain text"

      result = {
        professional_summary: content,
        work_experiences: [],
        skills: [],
        educations: [],
        certifications: [],
        languages: [],
        ats_optimization_notes: "Response was not in expected JSON format",
        generation_notes: "Response was not in expected JSON format",
        tokens_used: tokens_used,
        raw_response: content
      }

      Rails.logger.info "Fallback Professional Summary: #{result[:professional_summary].truncate(200)}"

      result
    end
  end

  def update_cv_generation_success(result)
    @cv_generation.update!(
      generated_content: result[:professional_summary],
      status: "processing", # Keep as processing until PDF is generated
      tokens_used: result[:tokens_used],
      metadata: @cv_generation.metadata.merge({
        work_experiences: result[:work_experiences],
        skills: result[:skills],
        educations: result[:educations],
        certifications: result[:certifications],
        languages: result[:languages],
        ats_optimization_notes: result[:ats_optimization_notes],
        generation_notes: result[:generation_notes],
        raw_response: result[:raw_response]
      })
    )
  end

  def create_or_update_resume(result)
    Rails.logger.info "=== CREATING/UPDATING RESUME ==="
    Rails.logger.info "Resume ID Present: #{@resume_id.present?}"

    if @resume_id
      # Update existing resume
      Rails.logger.info "Updating existing resume with ID: #{@resume_id}"
      update_existing_resume(result)
    else
      # Create new resume
      Rails.logger.info "Creating new resume"
      create_new_resume(result)
    end
  end

  def update_existing_resume(result)
    Rails.logger.info "=== UPDATING EXISTING RESUME ==="
    resume = Resume.find(@resume_id)
    Rails.logger.info "Found Resume: ID #{resume.id}, Name: #{resume.complete_name}"

    # Update only the professional summary
    Rails.logger.info "Updating professional summary"
    Rails.logger.info "New Professional Summary: #{result[:professional_summary].truncate(200)}"

    resume.update!(
      professional_summary: result[:professional_summary],
      summary: result[:professional_summary]
    )

    # Reload the resume to ensure we have the latest data
    resume.reload
    Rails.logger.info "Resume updated successfully"
    Rails.logger.info "Updated Professional Summary: #{resume.professional_summary.truncate(100)}"
  end

  def create_new_resume(result)
    Rails.logger.info "=== CREATING NEW RESUME ==="

    # Create new resume with basic information and professional summary only
    resume_data = {
      complete_name: @options[:complete_name] || "Generated CV",
      email: @options[:email] || "user@example.com",
      professional_summary: result[:professional_summary],
      summary: result[:professional_summary]
    }

    Rails.logger.info "Resume Data:"
    Rails.logger.info "  Complete Name: #{resume_data[:complete_name]}"
    Rails.logger.info "  Email: #{resume_data[:email]}"
    Rails.logger.info "  Professional Summary: #{resume_data[:professional_summary].truncate(200)}"

    resume = Resume.create!(resume_data)
    Rails.logger.info "New Resume Created: ID #{resume.id}"

    # Update the CV generation record with the new resume ID
    @cv_generation.update!(resume_id: resume.id)
    Rails.logger.info "CV Generation record updated with Resume ID: #{resume.id}"
  end

  def update_work_experiences(resume, work_experiences_data)
    # This method is no longer used since we only generate professional summaries
    # Keeping for backward compatibility
  end

  def update_skills(resume, skills_data)
    # This method is no longer used since we only generate professional summaries
    # Keeping for backward compatibility
  end

  def update_educations(resume, educations_data)
    # This method is no longer used since we only generate professional summaries
    # Keeping for backward compatibility
  end

  def update_certifications(resume, certifications_data)
    # This method is no longer used since we only generate professional summaries
    # Keeping for backward compatibility
  end

  def update_languages(resume, languages_data)
    # This method is no longer used since we only generate professional summaries
    # Keeping for backward compatibility
  end

  def generate_pdf_for_resume
    Rails.logger.info "=== GENERATING PDF FOR RESUME ==="

    begin
      # Get the resume that was created or updated - reload to get latest data
      resume = if @resume_id
        Resume.find(@resume_id)
      else
        @cv_generation.resume
      end

      # Reload the resume to ensure we have the latest data
      resume.reload
      Rails.logger.info "Resume for PDF generation: ID #{resume.id}, Name: #{resume.complete_name}"
      Rails.logger.info "Professional Summary for PDF: #{resume.professional_summary&.truncate(100)}"
      Rails.logger.info "Professional Summary English: #{resume.professional_summary_english&.truncate(100)}"
      Rails.logger.info "CV Generation Content: #{@cv_generation.generated_content&.truncate(100)}"

      # Use the generated content from CV generation instead of resume data
      Rails.logger.info "Using generated content for PDF: #{@cv_generation.generated_content&.truncate(100)}"
      
      # Generate PDF using the existing service but with generated content
      pdf_service = ResumePdfService.new(resume, @cv_generation.generated_content)
      html_content = pdf_service.generate

      Rails.logger.info "Generated HTML content length: #{html_content.length} characters"

      # Generate PDF using WickedPDF
      Rails.logger.info "About to generate PDF with WickedPDF..."
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        page_size: "A4",
        orientation: "Portrait",
        margin: {
          top: 0.5,
          bottom: 0.5,
          left: 0.5,
          right: 0.5
        },
        encoding: "UTF-8",
        print_media_type: true,
        disable_smart_shrinking: true,
        no_stop_slow_scripts: true,
        enable_forms: false,
        disable_external_links: true,
        disable_internal_links: true,
        page_offset: 0,
        book: false,
        default_header: false,
        default_footer: false,
        dpi: 300,
        image_quality: 100,
        zoom: 1.0
      )

      Rails.logger.info "Generated PDF size: #{pdf.bytesize} bytes"
      Rails.logger.info "PDF starts with: #{pdf[0..50]}"

      # Store PDF data in database instead of file system
      filename = "#{resume.complete_name.parameterize}_generated_cv.pdf"

      # Update CV generation record with PDF data
      @cv_generation.update!(
        generated_content: @cv_generation.generated_content, # Keep existing content
        metadata: @cv_generation.metadata.merge({
          pdf_generated: true,
          pdf_filename: filename,
          pdf_size: pdf.bytesize,
          pdf_data: Base64.encode64(pdf) # Store PDF as base64 in metadata
        })
      )

      Rails.logger.info "PDF data stored in database (Base64 encoded)"
      Rails.logger.info "Updated CV Generation metadata: #{@cv_generation.metadata}"

      Rails.logger.info "CV Generation record updated with PDF information"

    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"

      # Update CV generation record with error
      @cv_generation.update!(
        metadata: @cv_generation.metadata.merge({
          pdf_generated: false,
          pdf_error: e.message
        })
      )

      # Don't raise the error - PDF generation failure shouldn't fail the entire job
      Rails.logger.warn "PDF generation failed but CV generation completed successfully"
    end
  end

  def handle_cv_generation_error(error)
    @cv_generation.update!(
      status: "failed",
      generated_content: "CV generation failed: #{error.message}",
      metadata: @cv_generation.metadata.merge({
        error: error.message,
        backtrace: error.backtrace.first(5)
      })
    )

    # Log the error
    Rails.logger.error "CV Generation failed for user #{@user_id}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
  end
end
