require "prawn"
require "prawn/table"
require "net/http"
require "uri"
require "json"
require "base64"
require "ostruct" # For potentially complex data parsing
require "active_support/core_ext/hash/keys" # Needed for deep_symbolize_keys

# Mock classes for demonstration outside a full Rails environment.
# In a real Rails app, these models (Resume, CvGeneration, User, etc.) would already exist.
# class Resume < OpenStruct
#   def work_experiences; self[:work_experiences] || []; end
#   def skills; self[:skills] || []; end
#   def educations; self[:educations] || []; end
#   def certifications; self[:certifications] || []; end
#   def languages; self[:languages] || []; end
#   def update!(attributes); self.marshal_load(self.marshal_dump.merge(attributes)); end
#   def self.find(id); new(id: id); end
# end
# class CvGeneration < OpenStruct
#   def update!(attributes); self.marshal_load(self.marshal_dump.merge(attributes)); end
#   def self.find(id); new(id: id, metadata: {}); end
# end
# class User < OpenStruct
#   def cv_generations; self[:cv_generations] || []; end
#   def self.find(id); new(id: id); end
# end
# Rails = OpenStruct.new(logger: Logger.new(STDOUT), application: OpenStruct.new(credentials: { azure: { openai_api_key: "FAKE_KEY" } }))


class CvGeneratorJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  # Version control for PDF generation - increment this when making layout changes
  PDF_VERSION = "2.1"  # Incrementing to force regeneration

  def perform(job_description, user_id, resume_id = nil, options = {})
    Rails.logger.info "=== CV GENERATOR JOB STARTED ==="
    Rails.logger.info "Job Description: #{job_description.truncate(200)}"
    # ... (omitted logging for brevity)

    @job_description = job_description
    @user_id = user_id
    @resume_id = resume_id
    @options = options.transform_keys(&:to_sym)

    # Default options for cache handling
    @options[:force_pdf_regeneration] ||= false
    @options[:pdf_cache_hours] ||= 24

    # Find or create the CvGeneration record for this run
    @cv_generation = find_cv_generation_record
    if @cv_generation.nil?
      Rails.logger.info "Creating CvGeneration record for processing state"
      @cv_generation = CvGeneration.create!(
        user_id: @user_id,
        resume_id: @resume_id,
        job_description: @job_description,
        generated_content: nil,
        ai_model: "gpt-4.1-mini",
        status: "processing",
        tokens_used: nil,
        metadata: (@options || {})
      )
    end

    # For existing resumes, do NOT update any fields or sections. Only use the AI summary in the generated CV metadata/PDF.
    if @resume_id
      Rails.logger.info "✅ Not mutating existing resume #{@resume_id}; using it as source only."
    end
      # Load existing resume data
      if @resume_id
        @existing_resume = Resume.find(@resume_id)
        Rails.logger.info "📋 Loaded existing resume ID: #{@existing_resume.id}"
        Rails.logger.info "📋 Resume has #{@existing_resume.skills.count} skills"
        Rails.logger.info "📋 First skill: #{@existing_resume.skills.first&.attributes&.inspect}"
      end

      # Process the CV generation using Azure OpenAI
      result = call_azure_openai_api

  # Update the CV generation record with success (full structure stored in metadata)
  update_cv_generation_success(result)

      # Create or update resume with generated content
      # This logic now correctly creates/updates all associated models (WorkExperience, Skill, etc.)
      create_or_update_resume(result)

      # Generate PDF using the full structured data from metadata
      generate_pdf_for_resume

  # Now mark as completed after PDF is generated
  @cv_generation.update!(status: "completed")
      Rails.logger.info "=== CV GENERATION COMPLETED SUCCESSFULLY ==="

    rescue => e
      Rails.logger.error "=== CV GENERATION FAILED ==="
      Rails.logger.error "Error: #{e.message}"
      handle_cv_generation_error(e)
      raise e
    end

    private

  # --- Data Fetching and AI Communication (Minimal changes, mostly logging) ---

  def find_cv_generation_record
    # NOTE: You must implement this based on your database structure
    user = User.find(@user_id)
    user.cv_generations
        .where(job_description: @job_description, status: "processing")
        .order(created_at: :desc)
        .first
  end

  def call_azure_openai_api
    api_key = Rails.application.credentials.azure[:openai_api_key] || ENV["AZURE_OPENAI_API_KEY"]
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt
    response = make_openai_request(api_key, system_prompt, user_prompt)
    parse_openai_response(response)
  end

  def make_openai_request(api_key, system_prompt, user_prompt)
    uri = URI("https://craftcv.openai.azure.com/openai/deployments/gpt-4.1-mini/chat/completions?api-version=2025-01-01-preview")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["api-key"] = api_key

    payload = {
      messages: [
        { role: "system", content: [ { type: "text", text: system_prompt } ] },
        { role: "user", content: [ { type: "text", text: user_prompt } ] }
      ],
      temperature: (@options[:temperature] || 0.7).to_f,
      top_p: (@options[:top_p] || 0.95).to_f,
      max_tokens: (@options[:max_tokens] || 15000).to_i
    }

    request.body = payload.to_json

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 120
    # Use VERIFY_NONE to bypass CRL verification issues on macOS
    # In production, consider using a proper SSL certificate store
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      raise "OpenAI API request failed: #{response.code} - #{response.body}"
    end
  end

  # The system prompt ensures the AI provides ALL necessary structured data for the CV
  def build_system_prompt
    # ... (This remains the same JSON structure as in the original request, which is correct for generating structured data)
    <<~PROMPT
      You are an expert CV writer and ATS optimization specialist. Your task is to generate a complete, professional CV that will pass Applicant Tracking Systems (ATS) and impress hiring managers.

      CRITICAL REQUIREMENTS:
      1. Generate ONLY real, professional content - NEVER use placeholder text, test data, or sample content
      2. Create a comprehensive CV with multiple work experiences, skills, education, and certifications
      3. Generate content that is specific, measurable, and achievement-focused
      4. Use action verbs and quantifiable results where possible
      5. Ensure all content is relevant to the job description provided
      6. Write in clear, professional English suitable for international job applications
      7. Create enough content to fill 2-3 pages professionally

      FORMAT REQUIREMENTS:
      Return your response in JSON format with the following structure:
      {
        "professional_summary": "A compelling 3-4 sentence professional summary tailored to the job description",
        "work_experiences": [
          {
            "job_title": "Senior Software Engineer",
            "company": "TechCorp Solutions",
            "start_date": "2022-01",
            "end_date": null,
            "responsibilities": [
              "Led development of microservices architecture serving 100K+ users",
              "Mentored team of 5 junior developers and improved code quality by 40%",
              "Implemented CI/CD pipelines reducing deployment time by 60%",
              "Collaborated with product managers to deliver features 25% faster"
            ]
          }
          // ... more experiences
        ],
        "skills": [
          {
            "category": "Technical Skills",
            "names": ["JavaScript", "Python", "React", "Node.js", "PostgreSQL", "AWS", "Docker", "Git"]
          }
          // ... more skills
        ],
        "educations": [
          // ... education entries
        ],
        "certifications": [
          // ... certification entries
        ],
        "languages": [
          // ... language entries
        ],
        "ats_optimization_notes": "Optimized for ATS with relevant keywords, quantifiable achievements, and standard formatting",
        "generation_notes": "Generated comprehensive CV with realistic content tailored to job requirements"
      }

      IMPORTANT: Generate a complete, professional CV with enough content to create a compelling 2-3 page document. Include realistic work experiences, achievements, and skills that match the job description.
    PROMPT
  end

  def build_existing_cv_context
    return "" unless @existing_resume

    # Use the formatted data
    context = format_existing_resume_data

    # Create a formatted string with the existing CV data
    <<~EXISTING_CV
      EXISTING CV DATA:
      Please use the following existing CV data as a base and adapt it for the new job description.
      Keep relevant experiences and skills exactly as they are, ONLY update the professional summary.

      #{JSON.pretty_generate(context)}

      INSTRUCTIONS:
      1. Keep ALL existing experience data exactly as is - DO NOT modify any dates, companies, or responsibilities
      2. Keep ALL existing skills, education, certifications, and languages exactly as is
      3. ONLY rewrite the professional summary to target the new position
      4. Ensure the new summary highlights the most relevant aspects of the existing experience
      5. Focus on connecting past achievements to the new role requirements
    EXISTING_CV
  end

  def build_user_prompt
    existing_cv_data = @existing_resume ? build_existing_cv_context : ""
    base_requirements = []

    if @existing_resume
      # Focus only on updating the professional summary while preserving other sections
      base_requirements += [
        "IMPORTANT: Keep ALL existing work experience, skills, education, certifications, and languages exactly as they are",
        "ONLY generate a new professional summary that aligns with the job description",
        "Analyze the existing experience and skills to craft a targeted summary",
        "Highlight the most relevant aspects of the existing experience for this specific role",
        "Ensure the summary connects past achievements to the new role's requirements"
      ]
    else
      base_requirements += [
        "Generate a complete CV with all sections based on the job description",
        "Create realistic and relevant content that demonstrates expertise in the required areas",
        "Include quantifiable achievements and metrics where appropriate"
      ]
    end

    # Common requirements for the professional summary
    base_requirements += [
      "Make the professional summary concise and impactful (3-4 sentences)",
      "Include relevant keywords from the job description",
      "Emphasize achievements and skills that match the role",
      "Use strong action verbs and specific metrics"
    ]

    <<~PROMPT
      #{if @existing_resume
          "Please update ONLY the professional summary of the existing CV to target the following job description.#{' '}
           Keep all other sections (work experience, skills, education, etc.) EXACTLY as they are."
        else
          "Please generate a complete, professional CV for the following job description:"
        end}

      JOB DESCRIPTION:
      "#{@job_description}"

      #{existing_cv_data}

      REQUIREMENTS:
      #{base_requirements.map.with_index(1) { |req, i| "#{i}. #{req}" }.join("\n")}

      #{if @existing_resume
          "IMPORTANT: Return the existing CV data structure with ONLY the professional_summary field updated.#{' '}
           DO NOT modify any other fields (work_experiences, skills, education, certifications, languages)."
        end}

      Return the data in the JSON format specified in the system prompt.
    PROMPT
  end

  def format_existing_resume_data
    return {} unless @existing_resume

    # Return structured data of existing resume
    {
      professional_summary: @existing_resume.professional_summary,
      work_experiences: @existing_resume.work_experiences.map { |exp|
        # Handle responsibilities based on how they're stored
        responsibilities = if exp.respond_to?(:responsibilities)
          if exp.responsibilities.is_a?(Array)
            exp.responsibilities
          elsif exp.responsibilities.is_a?(String)
            exp.responsibilities.split("\n").reject(&:empty?)
          else
            []
          end
        elsif exp.respond_to?(:description)
          exp.description.split("\n").map(&:strip).reject(&:empty?)
        else
          []
        end

        {
          job_title: exp.job_title,
          company: exp.company,
          start_date: exp.start_date,
          end_date: (exp.respond_to?(:is_current) && exp.is_current) ? "Present" : exp.end_date,
          responsibilities: responsibilities
        }
      },
      skills: @existing_resume.skills.map { |skill|
        # Use skill_names array if available, otherwise fall back to name
        skill_list = if skill.skill_names.present?
          skill.skill_names
        elsif skill.name.present?
          [ skill.name ]
        else
          []
        end

        {
          category: skill.category || "Technical Skills",
          names: skill_list,
          details: skill_list.join(", ")  # Add details string for PDF generator
        }
      }.group_by { |s| s[:category] }.map { |category, skills|
        all_names = skills.flat_map { |s| s[:names] }.compact.reject(&:blank?)
        {
          category: category,
          names: all_names,
          details: all_names.join(", ")  # Convert array to comma-separated string
        }
      },
      educations: @existing_resume.educations.map { |edu|
        education_data = {
          degree: edu.degree,
          institution: edu.institution,
          start_date: edu.start_date,
          end_date: edu.end_date
        }
        education_data[:gpa] = edu.gpa if edu.respond_to?(:gpa) && edu.gpa.present?
        education_data
      },
      certifications: @existing_resume.certifications.map { |cert|
        {
          name: cert.name,
          organization: cert.organization,
          date: cert.date
        }
      },
      languages: @existing_resume.languages.map { |lang|
        {
          language: lang.language,
          proficiency: lang.proficiency
        }
      }
    }
  end

  def parse_openai_response(response)
    content = response["choices"][0]["message"]["content"]
    tokens_used = response["usage"]["total_tokens"]

    begin
      parsed_content = JSON.parse(content)

      if @existing_resume
        # When we have an existing resume, preserve ALL existing data
        existing_data = format_existing_resume_data
        result = {
          # Take only the new professional summary
          professional_summary: parsed_content["professional_summary"],
          # Explicitly preserve all existing data
          work_experiences: existing_data[:work_experiences] || [],
          skills: existing_data[:skills] || [],
          educations: existing_data[:educations] || [],
          certifications: existing_data[:certifications] || [],
          languages: existing_data[:languages] || [],
          # Include the optimization notes
          ats_optimization_notes: "Preserved all existing resume data",
          generation_notes: "Updated only professional summary while preserving all existing data",
          tokens_used: tokens_used,
          raw_response: content,
          using_existing_data: true
        }
      else
        # For new resumes, use all generated content
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
      end
      result
    rescue JSON::ParserError
      # Fallback: if not JSON, use the raw content as the summary
      {
        professional_summary: content,
        work_experiences: [], skills: [], educations: [], certifications: [], languages: [],
        ats_optimization_notes: "Response was not in expected JSON format",
        generation_notes: "Response was not in expected JSON format",
        tokens_used: tokens_used,
        raw_response: content
      }
    end
  end

  # --- Data Persistence (Crucial Fix for storing full JSON) ---

  def update_cv_generation_success(result)
    # Store only the professional summary in the main field, but the FULL structure in metadata

    # If we have an existing resume, use its data instead of AI-generated incomplete data
    if @existing_resume
      Rails.logger.info "Using existing resume data for skills, experience, etc."

      existing_data = format_existing_resume_data
      Rails.logger.info "📊 Existing resume skills count: #{@existing_resume.skills.count}"
      Rails.logger.info "📊 Formatted skills: #{existing_data[:skills].inspect}"

      generated_data = {
        professional_summary: result[:professional_summary], # Only use AI-generated summary
        work_experiences: existing_data[:work_experiences],
        skills: existing_data[:skills],
        educations: existing_data[:educations],
        certifications: existing_data[:certifications],
        languages: existing_data[:languages]
      }

      Rails.logger.info "📦 Generated data skills to be stored: #{generated_data[:skills].inspect}"
    else
      # For new CVs, use all AI-generated data
      Rails.logger.info "Using AI-generated data for new CV"

      generated_data = {
        professional_summary: result[:professional_summary],
        work_experiences: result[:work_experiences],
        skills: result[:skills],
        educations: result[:educations],
        certifications: result[:certifications],
        languages: result[:languages]
      }
    end

    safe_meta = (@cv_generation.metadata || {})
    @cv_generation.update!(
      generated_content: result[:professional_summary],
      status: "processing",
      tokens_used: result[:tokens_used],
      metadata: safe_meta.merge({
        generated_data: generated_data,
        ats_optimization_notes: result[:ats_optimization_notes],
        generation_notes: result[:generation_notes],
        raw_response: result[:raw_response]
      })
    )
  end

  # --- Resume Creation/Update (Remains largely the same, ensuring full population) ---

  def create_or_update_resume(result)
    # For existing resumes, do NOT update any fields or sections. Only use the AI summary in the generated CV metadata/PDF.
    if @resume_id
      resume = Resume.find(@resume_id)
      Rails.logger.info "✅ Not mutating existing resume #{@resume_id}; using it as source only."
      # Do NOT update professional_summary or any sections for existing resumes.
    else
      # For brand new, AI-only CVs, create a new Resume record and populate sections
      resume = create_new_resume(result)
      # Populate sections for new resumes only (not for existing builder CVs)
      populate_resume_sections(result)
    end

    # Ensure we're not losing any existing data (debug logging)
    Rails.logger.info "Skills count (source resume): #{resume.skills.count}"
    Rails.logger.info "Languages count (source resume): #{resume.languages.count}"
    Rails.logger.info "Certifications count (source resume): #{resume.certifications.count}"

    # Reload to ensure we have the latest data
    resume.reload
    resume
  end

  def update_existing_resume(result)
    # NOTE: This method is now merged/replaced by the logic in create_or_update_resume
    # but the original code structure might require it to remain for clarity.
    Rails.logger.info "update_existing_resume is deprecated; no mutation performed."
    Resume.find(@resume_id)
  end

  def create_new_resume(result)
    resume_data = {
      complete_name: @options[:complete_name] || "Generated CV",
      email: @options[:email] || "user@example.com",
  professional_summary: result[:professional_summary],
  summary: result[:professional_summary]
    }
    resume = Resume.create!(resume_data)
    @cv_generation.update!(resume_id: resume.id)
    resume
  end


  def populate_resume_sections(result)
    resume = @resume_id ? Resume.find(@resume_id) : @cv_generation.resume

    # Only populate sections for new resumes or when explicitly requested
    return if @resume_id && !@options[:force_update_sections]

    # Store the original data for existing resumes
    original_data = format_existing_resume_data if @resume_id

    # For each section, either use the generated data or preserve existing data
    if @resume_id
      # For existing resumes, only update if the section is empty
      populate_work_experiences(resume, original_data[:work_experiences]) if original_data[:work_experiences].present?
      populate_skills(resume, original_data[:skills]) if original_data[:skills].present?
      populate_educations(resume, original_data[:educations]) if original_data[:educations].present?
      populate_certifications(resume, original_data[:certifications]) if original_data[:certifications].present?
      populate_languages(resume, original_data[:languages]) if original_data[:languages].present?
    else
      # For new resumes, use the generated data
      populate_work_experiences(resume, result[:work_experiences]) if result[:work_experiences].present?
      populate_skills(resume, result[:skills]) if result[:skills].present?
      populate_educations(resume, result[:educations]) if result[:educations].present?
      populate_certifications(resume, result[:certifications]) if result[:certifications].present?
      populate_languages(resume, result[:languages]) if result[:languages].present?
    end
  end

  # The populate_xxx methods are left as placeholders but are assumed to correctly save the data
  # The original file's implementation of these methods looked correct for data saving.
  def populate_work_experiences(resume, work_experiences_data)
    return unless work_experiences_data.present?

    work_experiences_data.each do |exp_data|
      experience = resume.work_experiences.find_or_initialize_by(
        company: exp_data[:company],
        job_title: exp_data[:job_title],
        start_date: exp_data[:start_date]
      )

      experience.update!(
        end_date: exp_data[:end_date],
        responsibilities: Array(exp_data[:responsibilities])
      )
    end
  end

  def populate_skills(resume, skills_data)
    return unless skills_data.present?

    # Don't destroy existing skills, just add new ones if needed
    skills_data.each do |skill_group|
      category = skill_group[:category]
      names = if skill_group[:names].is_a?(Array)
        skill_group[:names]
      else
        skill_group[:names].to_s.split(",").map(&:strip)
      end

      next unless names.present?

      names.compact.each do |name|
        next if name.blank?
        # Use find_or_create_by to avoid duplicates
        existing_skill = resume.skills.find_by(category: category, name: name.strip)
        resume.skills.create!(category: category, name: name.strip) unless existing_skill
      end
    end
  end

  def populate_educations(resume, educations_data)
    return unless educations_data.present?

    educations_data.each do |edu_data|
      education = resume.educations.find_or_initialize_by(
        degree: edu_data[:degree],
        institution: edu_data[:institution]
      )

      education.update!(
        start_date: edu_data[:start_date],
        end_date: edu_data[:end_date],
        gpa: edu_data[:gpa]
      )
    end
  end

  def populate_certifications(resume, certifications_data)
    return unless certifications_data.present?

    certifications_data.each do |cert_data|
      certification = resume.certifications.find_or_initialize_by(
        name: cert_data[:name],
        organization: cert_data[:organization]
      )

      certification.update!(
        date: cert_data[:date]
      )
    end
  end

  def populate_languages(resume, languages_data)
    return unless languages_data.present?

    languages_data.each do |lang_data|
      language = resume.languages.find_or_initialize_by(
        language: lang_data[:language]
      )

      language.update!(
        proficiency: lang_data[:proficiency]
      )
    end
  end

  # --- PDF Generation (Rewritten for ATS compliance) ---
  def generate_pdf_for_resume
    Rails.logger.info "=== GENERATING PDF FOR RESUME WITH PRAWN ==="

    begin
      resume = @resume_id ? Resume.find(@resume_id).reload : @cv_generation.resume.reload

      # Get the full generated data from the CV generation metadata
      generated_data = @cv_generation.metadata["generated_data"]

      Rails.logger.info "📦 Raw metadata generated_data: #{generated_data.inspect}"
      Rails.logger.info "📦 Skills in metadata: #{generated_data&.dig('skills').inspect}"

      if generated_data.blank?
        Rails.logger.warn "No generated CV data found in metadata. Using resume data as fallback."
        # Create a fallback structure if AI data is missing
        work_experiences_data = resume.work_experiences.map do |we|
          {
            company: we.company,
            job_title: we.job_title,
            start_date: we.start_date,
            end_date: we.end_date,
            # Ensure responsibilities is always an array
            responsibilities: we.description.to_s.split("\n").map(&:strip).reject(&:blank?)
          }
        end

        Rails.logger.info "Created work experiences data from resume: #{work_experiences_data.inspect}"

        generated_data = {
          professional_summary: resume.professional_summary,
          work_experiences: work_experiences_data,
          skills: resume.skills.group_by(&:category).map { |c, s|
            skill_names = s.flat_map { |skill|
              if skill.skill_names.present?
                skill.skill_names
              elsif skill.name.present?
                [ skill.name ]
              else
                []
              end
            }.compact.reject(&:blank?)

            {
              category: c,
              names: skill_names,
              details: skill_names.join(", ")  # Add details for PDF generator
            }
          },
          educations: resume.educations.map(&:attributes),
          certifications: resume.certifications.map { |cert|
            { name: cert.name, organization: cert.organization, date: cert.date }
          },
          languages: resume.languages.map { |lang|
            { language: lang.language, proficiency: lang.proficiency }
          }
        }.deep_symbolize_keys
      else
        generated_data = generated_data.deep_symbolize_keys

        # Normalize work experiences structure
        if generated_data[:work_experiences].present?
          generated_data[:work_experiences].each do |exp|
            # Ensure responsibilities is always a properly formatted array
            if exp[:responsibilities].blank? && exp[:description].present?
              # Convert description to responsibilities if responsibilities is missing
              exp[:responsibilities] = exp[:description].to_s.split("\n").map(&:strip).reject(&:blank?)
            elsif exp[:responsibilities].is_a?(String)
              # Convert string responsibilities to array
              exp[:responsibilities] = exp[:responsibilities].split("\n").map(&:strip).reject(&:blank?)
            end
          end

          Rails.logger.info "Normalized work experiences: #{generated_data[:work_experiences].first(2).inspect}"
        end
      end

      # Force regeneration during initial job run and respect cache control afterward
      # When a job is first run (status is "processing"), always regenerate regardless of cache settings
      first_generation = @cv_generation.status == "processing"
      should_regenerate = first_generation || pdf_regeneration_needed?

      # Log the reason for regeneration
      if first_generation
        Rails.logger.info "Generating PDF for first time (initial job run)"
      elsif should_regenerate
        Rails.logger.info "Regenerating PDF due to template changes or cache expiration"
      else
        Rails.logger.info "Using cached PDF from previous generation"
      end

      # Always regenerate on first run or when needed
      if first_generation || should_regenerate
        # Use the AtsPdfGenerator service for better ATS compliance
        result = AtsPdfGenerator.generate_pdf(resume, generated_data)
        pdf = File.read(result[:path])
        filename = result[:filename]

        # Store PDF with version information and timestamp
        @cv_generation.update!(
          metadata: @cv_generation.metadata.merge({
            pdf_generated: true,
            pdf_filename: filename,
            pdf_size: pdf.bytesize,
            pdf_data: Base64.encode64(pdf),
            pdf_version: PDF_VERSION,
            pdf_generated_at: Time.now.to_i,
            pdf_cache_key: generate_pdf_cache_key(resume, generated_data)
          })
        )
        Rails.logger.info "PDF data stored in database (Base64 encoded)"
      else
        Rails.logger.info "Using cached PDF version (#{@cv_generation.metadata['pdf_version']})"
      end

    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      @cv_generation.update!(metadata: @cv_generation.metadata.merge({
        pdf_generated: false,
        pdf_error: e.message
      }))
      raise e
    end
  end

  def generate_section_title(pdf, title)
    pdf.move_down 10  # Reduced spacing before section title
    # Use all caps and bold for section headings (more ATS friendly)
    pdf.fill_color "000000" # Black color for better ATS parsing
    pdf.text title.upcase, size: 12, style: :bold
    pdf.stroke_color "000000"
    pdf.stroke_horizontal_rule
    pdf.move_down 8  # Reduced spacing after title
  end

  def generate_prawn_pdf(resume, data)
    Rails.logger.info "Starting PDF generation for #{resume.complete_name}"
    pdf_content = StringIO.new

    Prawn::Document.new(force_encoding: true, margin: 36) do |pdf|
      # Use core PDF font with encoding set
      pdf.font "Helvetica", enable_smart_quotes: false do
        # Header Section
        pdf.text resume.complete_name.to_s.strip, size: 20, style: :bold, align: :center
        pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: 10, align: :center
        pdf.move_down 20

        # Professional Summary
        if data[:professional_summary].present?
          pdf.text "PROFESSIONAL SUMMARY", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 10
          summary = resume.professional_summary_english.presence ||
                   resume.professional_summary.presence ||
                   data[:professional_summary].to_s.strip
          pdf.text summary, size: 10
          pdf.move_down 20
        end

        # Education Section
        if data[:educations].present? && data[:educations].any?
          pdf.text "EDUCATION", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 10
          Array(data[:educations]).each do |education|
            # Draw degree and date on the same line
            degree = education[:degree].to_s.strip
            date_text = "#{education[:start_date]} - #{education[:end_date]}"

            pdf.float do
              pdf.text date_text, size: 10, align: :right
            end
            pdf.text degree, size: 11, style: :bold

            # Institution on next line
            pdf.text education[:institution].to_s.strip, size: 10
            pdf.move_down 5
          end
          pdf.move_down 15
        end

        # Work Experience Section
        if data[:work_experiences].present? && data[:work_experiences].any?
          pdf.text "WORK EXPERIENCE", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 10

          # Sort experiences by start_date in reverse chronological order
          sorted_experiences = Array(resume.work_experiences).sort_by do |exp|
            begin
              # Handle current position
              if exp.is_current
                Time.current.to_i
              else
                # Parse date in YYYY-MM format
                date_str = exp.start_date.to_s
                if date_str =~ /^\d{4}-\d{2}$/
                  Date.strptime(date_str, "%Y-%m").to_time.to_i
                else
                  # Default to oldest date if invalid format
                  Date.new(1900, 1, 1).to_time.to_i
                end
              end
            rescue
              # Default to oldest date if parsing fails
              Date.new(1900, 1, 1).to_time.to_i
            end
          end.reverse  # Reverse to get descending order

          sorted_experiences.each do |experience|
            # Display date in top right corner
            date_text = "#{experience.start_date} - #{experience.is_current ? 'Present' : experience.end_date}"
            pdf.float do
              pdf.text date_text, size: 10, align: :right
            end

            # Display job title in bold with proper spacing - preserve original case
            pdf.text experience.job_title.to_s.strip, size: 11, style: :bold
            pdf.move_down 2  # Reduced space between title and company
            # Display company name under job title - preserve original case
            pdf.text experience.company.to_s.strip, size: 10
            pdf.move_down 4  # Space between company and responsibilities

            # Get responsibilities from the work experience
            raw_responsibilities = experience.responsibilities.presence || []

            # Ensure we have an array of responsibilities
            responsibilities = if raw_responsibilities.is_a?(String)
              # If it's a string, it might be a JSON array string, try to parse it
              begin
                JSON.parse(raw_responsibilities)
              rescue
                [ raw_responsibilities ] # If parsing fails, treat it as a single responsibility
              end
            else
              Array(raw_responsibilities)
            end

            # Add bullet points to each responsibility
            pdf.move_down 5  # Space before responsibilities
            responsibilities.each do |responsibility|
              next if responsibility.blank?

              pdf.indent(6) do  # Indent for bullet points
                pdf.formatted_text([
                  { text: "• ", size: 10 },
                  { text: responsibility.to_s.strip, size: 10 }  # Clean up and use exactly as entered
                ])
              end
              pdf.move_down 4  # Space between bullet points
            end

            pdf.move_down 12  # Space between different work experiences
          end
          pdf.move_down 15
        end

        # Skills Section
        if data[:skills].present? && data[:skills].any?
          pdf.text "SKILLS", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 8

          Array(data[:skills]).each do |skill|
            category = skill[:category].to_s.strip
            details = skill[:details].to_s.strip

            unless category.empty? && details.empty?
              # Draw the category name in bold with a colon
              pdf.font("Helvetica-Bold") do
                pdf.text "#{category}:", size: 10, align: :left
              end

              # Add details on the next line with proper indentation
              pdf.move_down 2
              pdf.indent(15) do
                pdf.text details,
                        size: 10,
                        align: :left,
                        leading: 2
              end

              # Add space between skill categories
              pdf.move_down 6
            end
          end
          pdf.move_down 15
        end

        # Certifications Section
        if data[:certifications].present? && data[:certifications].any?
          pdf.text "CERTIFICATIONS", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 8

          Array(data[:certifications]).each do |certification|
            name = certification[:name].to_s.strip
            org = certification[:organization].to_s.strip
            date = certification[:date].to_s.strip

            unless name.empty?
              # Create a bounding box for each certification entry
              pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width, height: 20) do
                # Date on the right
                if date.present?
                  pdf.bounding_box([ pdf.bounds.width - 80, pdf.bounds.top ], width: 80) do
                    pdf.text date, size: 10, align: :right
                  end
                end

                # Name and organization on the left
                pdf.bounding_box([ 0, pdf.bounds.top ], width: pdf.bounds.width - 90) do
                  pdf.font("Helvetica-Bold") { pdf.text "#{name}     ", size: 10 }
                  pdf.move_up 11.5
                  pdf.indent(pdf.width_of("#{name}     ", size: 10)) do
                    pdf.font("Helvetica") { pdf.text org.to_s, size: 10 }
                  end
                end
              end
              pdf.move_down 4
            end
          end
          pdf.move_down 15
        end

        # Languages Section
        if data[:languages].present? && data[:languages].any?
          pdf.text "LANGUAGES", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 8
          Array(data[:languages]).each do |language|
            lang = language[:language].to_s.strip
            prof = language[:proficiency].to_s.strip
            unless lang.empty? && prof.empty?
              # Add proficiency level aligned to the right
              pdf.float do
                pdf.text prof, size: 10, align: :right
              end
              # Add language name in bold
              pdf.font("Helvetica-Bold") { pdf.text lang, size: 10 }
            end
            pdf.move_down 2  # Small space between languages
          end
        end
      end
    end

    # Return the generated PDF content
    pdf_content.string

    Rails.logger.info "Including sections: #{sections.join(', ')}"

    pdf = Prawn::Document.new(
      page_size: "A4",
      margin: [ 36, 36, 36, 36 ],  # Compact margins to avoid excessive pages
      page_layout: :portrait,
      compress: true,  # Enable compression
      info: {
        Title: "Resume - #{resume.complete_name}",
        Author: "CVCraft",
        Creator: "CVCraft Resume Generator",
        Producer: "Prawn via CVCraft",
        CreationDate: Time.now
      }
    )

    # Set up basic document properties with ATS-friendly fonts
    pdf.font_families.update("Arial" => {
      normal: "Helvetica", # Fallback to Helvetica
      italic: "Helvetica-Oblique",
      bold: "Helvetica-Bold",
      bold_italic: "Helvetica-BoldOblique"
    })

    pdf.font "Arial"
  pdf.font_size 10.5  # Slightly smaller to fit more content
  pdf.default_leading 2  # Reduced spacing between lines
  # Create a sections array to track what's included
  sections = []

    # Ensure we start at the top of the page
    pdf.go_to_page(1)
    pdf.move_cursor_to(pdf.bounds.top)

    # Name at the top - larger and bold but left-aligned for ATS
    pdf.text resume.complete_name.to_s.strip, size: 18, style: :bold
    pdf.move_down 6

    # Contact info on separate lines for better ATS parsing
    if resume.email.present?
      pdf.text "Email: #{resume.email}", size: 10
    end

    if resume.phone_number.present?
      pdf.text "Phone: #{resume.phone_number}", size: 10
    end

    location = [ resume.city, resume.country ].compact.join(", ")
    if location.present?
      pdf.text "Location: #{location}", size: 10
    end

    # Simple black line for better ATS compatibility
    pdf.stroke_color "000000"
    pdf.stroke_horizontal_rule
    pdf.move_down 20

    # Professional Summary
    if data[:professional_summary].present?
      generate_section_title(pdf, "Professional Summary")
      pdf.text data[:professional_summary].to_s.strip, size: 10, align: :justify
      pdf.move_down 10
    end

    # Education - ATS friendly format with compact layout
    if data[:educations].present?
      generate_section_title(pdf, "Education")
      data[:educations].each do |education|
        # Degree with dates to the right
        pdf.text education[:degree].to_s.strip, size: 11, style: :bold
        pdf.move_up 11
        pdf.text "#{education[:start_date]} - #{education[:end_date]}", align: :right, size: 10

        # Institution and GPA on same line when possible
        institution_text = education[:institution].to_s.strip
        if education[:gpa]
          institution_text += " - GPA: #{education[:gpa]}"
        end
        pdf.text institution_text, size: 10
        pdf.move_down 7  # Reduced space between education entries
      end
    end

    # Work Experience
    if data[:work_experiences].present?
      generate_section_title(pdf, "Work Experience")

      Rails.logger.info "Work Experiences Data: #{data[:work_experiences].inspect}"

      # Sort experiences with current jobs first, then by most recent start date
      sorted_experiences = data[:work_experiences].sort_by do |exp|
        is_current = exp[:end_date].to_s.downcase.include?("present")
        # Current jobs go first, then sort by start date (descending)
        [ is_current ? 0 : 1, -(exp[:start_date].to_s.gsub(/\D/, "").to_i) ]
      end

      sorted_experiences.each do |exp|
        # Optimized layout to save space but remain ATS-friendly
        # Job title with dates to the right
        pdf.text exp[:job_title].to_s.strip, size: 11, style: :bold, inline_format: true
        pdf.move_up 11
        pdf.text "<color rgb='000000'>#{exp[:start_date]} - #{exp[:end_date].to_s.capitalize}</color>",
          align: :right, size: 10, inline_format: true

        # Company name
        pdf.text exp[:company].to_s.strip, size: 10.5
        pdf.move_down 3

        # Debug responsibilities
        Rails.logger.info "Responsibilities for job '#{exp[:job_title]}': #{exp[:responsibilities].inspect}"

        # Handle responsibilities in various formats
        responsibilities = if exp[:responsibilities].is_a?(Array)
          exp[:responsibilities]
        elsif exp[:responsibilities].is_a?(String)
          exp[:responsibilities].split("\n").map(&:strip)
        elsif exp[:description].present?
          # Fallback to description if responsibilities not found
          exp[:description].to_s.split("\n").map(&:strip)
        else
          []
        end

        # Compact bullet formatting - ensure we have actual content
        if responsibilities.any?
          responsibilities.each do |resp|
            next if resp.blank?
            pdf.indent(8) do
              pdf.text "• #{resp.to_s.strip}", size: 10, leading: 1.5
            end
          end
        elsif exp[:description].present?
          # Fallback to showing the entire description if no individual responsibilities
          pdf.indent(8) do
            pdf.text "• #{exp[:description].to_s.strip}", size: 10, leading: 1.5
          end
        end

        pdf.move_down 8  # Reduced space between positions
      end
    end

    # Skills - ATS optimized format with compact layout
    if data[:skills].present?
      generate_section_title(pdf, "Skills")

      # Group skills by category for better organization
      data[:skills].each do |skill_group|
        next unless skill_group[:category].present?

        # Category header
        pdf.text skill_group[:category].to_s, size: 11, style: :bold

        # Get skills list from either format
        skill_list = if skill_group[:names].is_a?(Array)
          skill_group[:names]
        elsif skill_group[:names].is_a?(String)
          skill_group[:names].split(",").map(&:strip)
        elsif skill_group[:details].present?
          skill_group[:details].split(",").map(&:strip)
        else
          []
        end

        # Format and display skills
        if skill_list.any?
          pdf.text skill_list.join(" • "), size: 10
          pdf.move_down 5
        end
      end
      pdf.move_down 10
    end

    # Certifications - ATS friendly format with compact layout
    if data[:certifications].present?
      generate_section_title(pdf, "Certifications")
      data[:certifications].each do |cert|
        # Cert name with date to the right
        pdf.text cert[:name].to_s.strip, size: 10.5, style: :bold
        if cert[:date].present?
          pdf.move_up 10
          pdf.text cert[:date].to_s, align: :right, size: 10
        end

        # Combined organization and status when both present
        details = []
        details << cert[:organization] if cert[:organization].present?
        details << cert[:status] if cert[:status].present?

        if details.any?
          pdf.text details.join(" - "), size: 10
        end

        pdf.move_down 5  # Reduced space between certificates
      end
    end

    # Languages - ATS friendly format with compact layout
    if data[:languages].present?
      generate_section_title(pdf, "Languages")
      # Put all languages on one line if possible
      language_parts = data[:languages].map do |lang|
        "#{lang[:language]} (#{lang[:proficiency]})"
      end
      pdf.text language_parts.join(" | "), size: 10
    end # Closing if data[:languages].present?

    # Remove any empty pages at the end
    while pdf.page_count > 1
      pdf.go_to_page(pdf.page_count)
      # Check if the current page has any content by looking at its length
      if pdf.page.dictionary.data[:Contents].nil? ||
         (pdf.page.dictionary.data[:Contents].is_a?(Array) && pdf.page.dictionary.data[:Contents].empty?)
        pdf.delete_page
      else
        break
      end
      pdf.go_to_page(pdf.page_count - 1)
    end

    Rails.logger.info "PDF generation completed with #{pdf.page_count} pages"

    pdf.render
  end # Closing generate_prawn_pdf method

  def handle_cv_generation_error(e)
    if @cv_generation.nil?
      @cv_generation = find_cv_generation_record
    end
    if @cv_generation
      safe_meta = (@cv_generation.metadata || {})
      @cv_generation.update!(
        status: "failed",
        metadata: safe_meta.merge({
          error: e.message,
          error_backtrace: e.backtrace
        })
      )
    else
      Rails.logger.error "No CvGeneration record available to update error metadata"
    end
  end

  def pdf_cache_expired?
    return true unless @cv_generation.metadata["pdf_generated_at"]
    pdf_age_hours = (Time.now.to_i - @cv_generation.metadata["pdf_generated_at"].to_i) / 3600.0
    pdf_age_hours > (@options[:pdf_cache_hours] || 24)
  end

  def generate_pdf_cache_key(resume, data)
    key_parts = [
      resume.complete_name.to_s,
      resume.updated_at.to_i,
      PDF_VERSION,
      Digest::MD5.hexdigest(data.to_json)
    ]
    Digest::MD5.hexdigest(key_parts.join("|"))
  end
end # Closing CvGeneratorJob class
