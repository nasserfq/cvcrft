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
        ai_model: AiModel.default,
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
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt
    response = AiModel.complete(system: system_prompt, user: user_prompt,
                                temperature: (@options[:temperature] || 0.7).to_f, max_tokens: (@options[:max_tokens] || 15000).to_i)
    parse_openai_response(response)
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
    content = response.content
    tokens_used = AiModel.token_count(response)

    # Models differ on whether they fence their JSON. gpt-4.1-mini returned it
    # bare; Claude wraps it in ```json. Without this the parse raises and the
    # rescue below dumps the whole raw response into professional_summary.
    # The other four jobs already strip the fence.
    if (fenced = content.match(/```(?:json)?\s*(.*?)\s*```/m))
      content = fenced[1]
    end

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
        template_key = selected_ats_template_key
        result = AtsTemplatePdfService.generate_pdf(resume, generated_data, template: template_key)
        pdf = File.read(result[:path])
        filename = result[:filename]

        # Store PDF with version information and timestamp
        @cv_generation.update!(
          metadata: @cv_generation.metadata.merge({
            ats_template: template_key,
            pdf_generated: true,
            pdf_filename: filename,
            pdf_size: pdf.bytesize,
            pdf_data: Base64.encode64(pdf),
            pdf_version: PDF_VERSION,
            pdf_generated_at: Time.now.to_i,
            pdf_cache_key: generate_pdf_cache_key(resume, generated_data, template_key)
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

  def selected_ats_template_key
    AtsTemplatePdfService.normalize_template_key(
      @options[:ats_template] || @options["ats_template"] || @cv_generation.metadata["ats_template"]
    )
  end

  def pdf_regeneration_needed?
    return true if @options[:force_pdf_regeneration]
    return true if pdf_cache_expired?

    resume = @resume_id ? Resume.find(@resume_id) : @cv_generation.resume
    generated_data = (@cv_generation.metadata["generated_data"] || {}).deep_symbolize_keys
    template_key = selected_ats_template_key
    current_cache_key = generate_pdf_cache_key(resume, generated_data, template_key)

    @cv_generation.metadata["pdf_cache_key"] != current_cache_key
  end

  def generate_pdf_cache_key(resume, data, template_key = nil)
    template_key ||= selected_ats_template_key
    key_parts = [
      resume.complete_name.to_s,
      resume.updated_at.to_i,
      PDF_VERSION,
      template_key,
      Digest::MD5.hexdigest(data.to_json)
    ]
    Digest::MD5.hexdigest(key_parts.join("|"))
  end
end # Closing CvGeneratorJob class
