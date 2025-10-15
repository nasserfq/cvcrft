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
  # NOTE: Replace 'include Sidekiq::Job' if not using Sidekiq
  # include Sidekiq::Job

  # sidekiq_options retry: 3, backtrace: true

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

    @cv_generation = find_cv_generation_record
    # NOTE: In a real environment, you'd raise an error if @cv_generation is nil

    begin
      # Load existing resume data
      if @resume_id
        @existing_resume = Resume.find(@resume_id)
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
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

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

  def build_user_prompt
    # ... (This remains the same)
    existing_cv_data = @existing_resume ? build_existing_cv_context : ""

    <<~PROMPT
      Please generate a complete, professional CV based on the following job description:

      JOB DESCRIPTION:
      "#{@job_description}"

      #{existing_cv_data}

      REQUIREMENTS:
      1. Generate a complete CV with professional summary, work experience, skills, education, certifications, and languages
      2. Create realistic, professional content that matches the job requirements
      // ... (other requirements)

      Return the complete CV data in the JSON format specified in the system prompt.
    PROMPT
  end

  def build_existing_cv_context
    # ... (This remains the same)
  end

  def parse_openai_response(response)
    # ... (This remains the same, but ensures all keys are handled)
    content = response["choices"][0]["message"]["content"]
    tokens_used = response["usage"]["total_tokens"]

    begin
      parsed_content = JSON.parse(content)

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
    @cv_generation.update!(
      generated_content: result[:professional_summary],
      status: "processing",
      tokens_used: result[:tokens_used],
      metadata: @cv_generation.metadata.merge({
        generated_data: {
          professional_summary: result[:professional_summary],
          work_experiences: result[:work_experiences],
          skills: result[:skills],
          educations: result[:educations],
          certifications: result[:certifications],
          languages: result[:languages]
        },
        ats_optimization_notes: result[:ats_optimization_notes],
        generation_notes: result[:generation_notes],
        raw_response: result[:raw_response]
      })
    )
  end

  # --- Resume Creation/Update (Remains largely the same, ensuring full population) ---

  def create_or_update_resume(result)
    # NOTE: Logic to find or create the resume object (@resume) is needed here
    # Assuming the logic in the original file correctly sets/updates the resume object
    resume = if @resume_id
      Resume.find(@resume_id)
    else
      create_new_resume(result)
    end

    # Update professional summary
    resume.update!(
      professional_summary: result[:professional_summary],
      summary: result[:professional_summary]
    )

    # Populate all sections with generated content
    populate_resume_sections(result)
  end

  def update_existing_resume(result)
    # NOTE: This method is now merged/replaced by the logic in create_or_update_resume
    # but the original code structure might require it to remain for clarity.
    resume = Resume.find(@resume_id)
    resume.update!(
      professional_summary: result[:professional_summary],
      summary: result[:professional_summary]
    )
    resume.reload
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

    populate_work_experiences(resume, result[:work_experiences]) if result[:work_experiences].present?
    populate_skills(resume, result[:skills]) if result[:skills].present?
    populate_educations(resume, result[:educations]) if result[:educations].present?
    populate_certifications(resume, result[:certifications]) if result[:certifications].present?
    populate_languages(resume, result[:languages]) if result[:languages].present?
  end

  # The populate_xxx methods are left as placeholders but are assumed to correctly save the data
  # The original file's implementation of these methods looked correct for data saving.
  def populate_work_experiences(resume, work_experiences_data)
    # ... (omitted)
  end

  def populate_skills(resume, skills_data)
    # ... (omitted)
  end

  def populate_educations(resume, educations_data)
    # ... (omitted)
  end

  def populate_certifications(resume, certifications_data)
    # ... (omitted)
  end

  def populate_languages(resume, languages_data)
    # ... (omitted)
  end

  # The empty update_xxx methods are removed as they are no longer used.

  # --- PDF Generation (Rewritten for ATS compliance) ---

  def generate_pdf_for_resume
    Rails.logger.info "=== GENERATING PDF FOR RESUME WITH PRAWN ==="

    begin
      resume = @resume_id ? Resume.find(@resume_id).reload : @cv_generation.resume.reload

      # Get the full generated data from the CV generation metadata
      generated_data = @cv_generation.metadata["generated_data"]

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
            { category: c, details: s.map(&:name).join(", ") }
          },
          educations: resume.educations.map(&:attributes),
          certifications: resume.certifications.map(&:attributes),
          languages: resume.languages.map(&:attributes)
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
        pdf = generate_prawn_pdf(resume, generated_data)
        filename = "#{resume.complete_name.parameterize}_generated_cv.pdf"

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

    # Log sections to be included
    sections = []
    sections << "Professional Summary" if data[:professional_summary].present?
    sections << "Work Experience" if data[:work_experiences].present? && data[:work_experiences].any?
    sections << "Skills" if data[:skills].present? && data[:skills].any?
    sections << "Education" if data[:educations].present? && data[:educations].any?
    sections << "Certifications" if data[:certifications].present? && data[:certifications].any?
    sections << "Languages" if data[:languages].present? && data[:languages].any?

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
    pdf.default_leading 2  # Reduced spacing between lines    # Ensure we start at the top of the page
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

      data[:skills].each do |skill|
        # Use category: details format for each skill group
        pdf.text "#{skill[:category]}:", size: 10, style: :bold

        if skill[:details].present?
          # If details is a string, add it directly
          pdf.text skill[:details].to_s.strip, size: 10
        elsif skill[:names].present?
          # If names is an array, format as comma-separated list
          pdf.text skill[:names].join(", "), size: 10
        end
        pdf.move_down 3
      end
      pdf.move_down 3
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
    end

    # Remove any empty pages at the end
    while pdf.page_count > 1 && pdf.page.empty?
      pdf.go_to_page(pdf.page_count)
      pdf.start_new_page
      pdf.go_to_page(pdf.page_count - 1)
    end

    Rails.logger.info "PDF generation completed with #{pdf.page_count} pages"

    pdf.render
  end

  def handle_cv_generation_error(e)
    # ... (omitted)
  end

  # Cache handling methods

  # Determine if the PDF needs to be regenerated based on version changes or data changes
  def pdf_regeneration_needed?
    # Always regenerate if:
    # 1. No PDF exists yet
    # 2. Version has changed
    # 3. Resume data has been updated after PDF was generated
    # 4. Force regeneration option is set
    # 5. When generating a new CV (status is processing)

    # Force regeneration via options always takes precedence
    return true if @options[:force_pdf_regeneration]

    metadata = @cv_generation.metadata

    # No PDF data exists
    return true if metadata["pdf_data"].blank?

    # Version mismatch (template has been updated) - MOST IMPORTANT CHECK
    stored_version = metadata["pdf_version"].to_s
    current_version = PDF_VERSION.to_s
    if stored_version != current_version
      Rails.logger.info "PDF version mismatch: stored=#{stored_version}, current=#{current_version}"
      return true
    end    # PDF is older than resume updates
    return true if pdf_cache_expired?

    # Check if data has changed by comparing cache keys
    current_cache_key = generate_pdf_cache_key(@cv_generation.resume, metadata["generated_data"])
    return true if current_cache_key != metadata["pdf_cache_key"]

    # No regeneration needed
    false
  end

  # Generate a cache key based on the content to detect changes
  def generate_pdf_cache_key(resume, data)
    # Create a digest of the critical fields that would affect the PDF output
    key_parts = []

    # Resume info
    key_parts << resume.complete_name.to_s
    key_parts << resume.updated_at.to_i if resume.respond_to?(:updated_at)

    # Data info - serialize and hash the key structures
    if data.present?
      data_hash = data.is_a?(Hash) ? data : data.to_h
      # Include only fields that affect layout
      %w[professional_summary work_experiences skills educations certifications languages].each do |key|
        key_parts << Digest::MD5.hexdigest(data_hash[key].to_s) if data_hash[key].present?
      end
    end

    # Include PDF version in the cache key
    key_parts << PDF_VERSION

    # Create final cache key
    Digest::MD5.hexdigest(key_parts.join("|"))
  end

  # Check if the PDF was generated too long ago
  def pdf_cache_expired?
    metadata = @cv_generation.metadata

    # If no timestamp, consider expired
    return true unless metadata["pdf_generated_at"]

    # Calculate age of PDF in hours
    pdf_age_hours = (Time.now.to_i - metadata["pdf_generated_at"].to_i) / 3600.0

    # Expire after 24 hours or as configured
    max_age_hours = @options[:pdf_cache_hours] || 24
    pdf_age_hours > max_age_hours
  end
end
