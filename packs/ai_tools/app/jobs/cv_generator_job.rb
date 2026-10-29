require "prawn"
require "prawn/table"
require "json"
require "base64"
require "ostruct" # For potentially complex data parsing
require "active_support/core_ext/hash/keys" # Needed for deep_symbolize_keys

class CvGeneratorJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true

  # A generation that ran past the free allowance was paid with a credit
  # (Billing::UsageGate); options["overage_key"], a random id, is set only
  # then. A final failure gives the credit back. Safe to call twice.
  sidekiq_retries_exhausted do |job, _error|
    refund_overage(job["args"][1], job["args"][3])
  end

  def self.refund_overage(user_id, options)
    key = (options || {}).transform_keys(&:to_s)["overage_key"].presence
    user = key && User.find_by(id: user_id)
    Billing::UsageGate.refund!(user, :job_based_generation, key: key) if user
  end

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

    # The AI only rewrites the professional summary of a saved CV; it never
    # builds a new one. Fail before anything is created.
    raise ArgumentError, "resume_id is required" if @resume_id.blank?

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

    # Do NOT update any fields or sections of the saved resume. Only use the AI summary in the generated CV metadata/PDF.
    Rails.logger.info "✅ Not mutating existing resume #{@resume_id}; using it as source only."
      # Load the saved resume data
      @existing_resume = owned_resume
      Rails.logger.info "📋 Loaded existing resume ID: #{@existing_resume.id}"
      Rails.logger.info "📋 Resume has #{@existing_resume.skills.count} skills"
      Rails.logger.info "📋 First skill ID: #{@existing_resume.skills.first&.id}"
      @snapshot = CvGenerator::ResumeSnapshot.new(@existing_resume).to_h

      # Process the CV generation using Azure OpenAI
      result = call_azure_openai_api

  # Update the CV generation record with success (full structure stored in metadata)
  update_cv_generation_success(result)

      # Reload the saved resume (never mutated) before rendering the PDF
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

  # The resume must belong to the user this job runs for; resume_id comes
  # from the request, so never load it unscoped.
  def owned_resume
    Resume.find_by!(id: @resume_id, user_id: @user_id)
  end

  def find_cv_generation_record
    # NOTE: You must implement this based on your database structure
    user = User.find(@user_id)
    user.cv_generations
        .where(job_description: @job_description, status: "processing")
        .order(created_at: :desc)
        .first
  end

  def call_azure_openai_api
    prompts = CvGenerator::PromptBuilder.new(job_description: @job_description, snapshot: @snapshot)
    response = AiModel.complete(system: prompts.system_prompt, user: prompts.user_prompt,
                                temperature: (@options[:temperature] || 0.7).to_f, max_tokens: (@options[:max_tokens] || 10000).to_i,
                                check: "Is the professional summary in the output strong, in English, tailored to the job in the input, and free of facts the input does not support?")
    result = CvGenerator::ResponseParser.new(snapshot: @snapshot).call(response)
    result[:professional_summary] = CvGenerator::EnglishSummary.new.call(result[:professional_summary])
    result
  end

  # --- Data Persistence (Crucial Fix for storing full JSON) ---

  def update_cv_generation_success(result)
    Rails.logger.info "📊 Existing resume skills count: #{@existing_resume.skills.count}"
    CvGenerator::ResultPersister.new(@cv_generation).record!(result, snapshot: @snapshot)
  end

  # --- Saved resume (read only; never created or updated here) ---

  def create_or_update_resume(result)
    # The saved resume is never mutated: do NOT update professional_summary or
    # any sections. Only the AI summary is used, in the generated CV metadata/PDF.
    resume = owned_resume
    Rails.logger.info "✅ Not mutating existing resume #{@resume_id}; using it as source only."

    # Ensure we're not losing any existing data (debug logging)
    Rails.logger.info "Skills count (source resume): #{resume.skills.count}"
    Rails.logger.info "Languages count (source resume): #{resume.languages.count}"
    Rails.logger.info "Certifications count (source resume): #{resume.certifications.count}"

    # Reload to ensure we have the latest data
    resume.reload
    resume
  end

  # --- PDF Generation (Rewritten for ATS compliance) ---
  def generate_pdf_for_resume
    Rails.logger.info "=== GENERATING PDF FOR RESUME WITH PRAWN ==="

    begin
      resume = owned_resume.reload

      # Get the full generated data from the CV generation metadata
      generated_data = @cv_generation.metadata["generated_data"]

      Rails.logger.info "📦 Raw metadata generated_data keys: #{generated_data.respond_to?(:keys) ? generated_data.keys.inspect : "none"}"
      Rails.logger.info "📦 Skills in metadata: #{Array(generated_data&.dig('skills')).size}"

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

        Rails.logger.info "Created work experiences data from resume: #{work_experiences_data.size} entries"

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

          Rails.logger.info "Normalized work experiences: #{generated_data[:work_experiences].size} entries"
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

    resume = owned_resume
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
