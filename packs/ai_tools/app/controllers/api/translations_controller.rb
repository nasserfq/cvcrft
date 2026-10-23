class Api::TranslationsController < ApplicationController
  include CreditsUpsell
  before_action :authenticate_user!

  def translate_professional_summary
    begin
      # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
      remaining = usage_limits.remaining_summary_translations
      return render_translation_limit(:summary_translation) unless Billing::UsageGate.available?(current_user, :summary_translation)

      # Always enqueue a new AI translation job for every request

      user_id = current_user.id
      resume_id = owned_resume_id
      arabic_text = params[:arabic_text]

      # Validate input
      if arabic_text.blank?
        render json: { error: "Arabic text is required" }, status: :unprocessable_entity
        return
      end

      # Generate a unique job ID first
      job_id = SecureRandom.hex(12)

      charge = Billing::UsageGate.allow!(current_user, :summary_translation, key: job_id)
      return render_translation_limit(:summary_translation) if charge == :blocked

      job = AiTranslationJob.perform_async(
        arabic_text,
        user_id,
        resume_id,
        {
          "temperature" => 0.7,
          "max_tokens" => 500,
          "professional_summary" => true,
          "job_id" => job_id,
          "overage_kind" => ("summary_translation" if charge == :credit)
        }.compact
      )

      # Track translation event
      track_event("translation_requested", {
        type: "professional_summary",
        resume_id: resume_id,
        remaining: projected_remaining(remaining)
      })

      Rails.logger.info "[AI Translate] Job enqueued: #{job}, job_id: #{job_id}"
      render json: {
        job_id: job_id,
        status: "queued",
        remaining_summary: projected_remaining(remaining),
        unlimited: usage_limits.unlimited?,
        **charge_json(charge, :summary_translation),
        message: "Translation job has been queued. Please poll for status."
      }
    rescue => e
      Billing::UsageGate.refund!(current_user, :summary_translation, key: job_id) if charge == :credit
      Rails.logger.error "[AI Translate] Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Translation failed", message: e.message }, status: :internal_server_error
    end
  end

  def translate_job_descriptions
    begin
      # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
      remaining = usage_limits.remaining_jobs_translations
      return render_translation_limit(:jobs_translation) unless Billing::UsageGate.available?(current_user, :jobs_translation)

      user_id = current_user.id
      resume_id = owned_resume_id
      job_descriptions = params[:job_descriptions] # Array of {index, job_title, company, responsibilities}

      if job_descriptions.blank? || !job_descriptions.is_a?(Array)
        render json: { error: "Job descriptions array is required" }, status: :unprocessable_entity
        return
      end

      # Filter out empty job descriptions
      valid_jobs = job_descriptions.select do |job|
        job["responsibilities"]&.any? { |r| r.to_s.strip.present? }
      end

      if valid_jobs.empty?
        render json: { error: "No job descriptions with responsibilities to translate" }, status: :unprocessable_entity
        return
      end

      # Generate a unique job ID for tracking
      job_id = SecureRandom.hex(12)

      # Combine all job descriptions into one text for efficient translation
      combined_text = valid_jobs.map do |job|
        responsibilities = job["responsibilities"]&.select(&:present?)&.join("\n") || ""
        "[#{job['job_title']} - #{job['company']}]\n#{responsibilities}"
      end.join("\n\n---\n\n")

      charge = Billing::UsageGate.allow!(current_user, :jobs_translation, key: job_id)
      return render_translation_limit(:jobs_translation) if charge == :blocked

      job = AiTranslationJob.perform_async(
        combined_text,
        user_id,
        resume_id,
        {
          "temperature" => 0.7,
          "max_tokens" => 2000,
          "job_descriptions" => true,
          "job_id" => job_id,
          "job_indices" => valid_jobs.map { |j| j["index"] },
          "overage_kind" => ("jobs_translation" if charge == :credit)
        }.compact
      )

      # Track translation event
      track_event("translation_requested", {
        type: "job_descriptions",
        resume_id: resume_id,
        job_count: valid_jobs.size,
        remaining: projected_remaining(remaining)
      })

      Rails.logger.info "[AI Translate Jobs] Job enqueued: #{job}, job_id: #{job_id}"
      render json: {
        job_id: job_id,
        status: "queued",
        job_count: valid_jobs.size,
        remaining_jobs: projected_remaining(remaining),
        unlimited: usage_limits.unlimited?,
        **charge_json(charge, :jobs_translation),
        message: "Translation job has been queued for #{valid_jobs.size} job descriptions."
      }
    rescue => e
      Billing::UsageGate.refund!(current_user, :jobs_translation, key: job_id) if charge == :credit
      Rails.logger.error "[AI Translate Jobs] Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Translation failed", message: e.message }, status: :internal_server_error
    end
  end

  def translation_status
    begin
      job_id = params[:id]

      # Find the translation by job_id stored in metadata
      translation = AiTranslation.where(user_id: current_user.id)
                               .where("metadata->>'job_id' = ?", job_id)
                               .order(created_at: :desc)
                               .first

      if translation
        # Parse the metadata to get the structured translation data
        metadata = translation.metadata || {}

        # Check if this is a job descriptions translation
        is_job_descriptions = metadata["job_descriptions"] == true

        response_data = {
          id: translation.id,
          job_id: job_id,
          status: translation.status,
          arabic_text: translation.arabic_text,
          english_text: translation.english_text,
          translation_quality: translation.translation_quality,
          tokens_used: translation.tokens_used,
          created_at: translation.created_at,
          updated_at: translation.updated_at,
          # Add structured data from metadata
          skills_extracted: metadata["skills_extracted"] || [],
          translation_notes: metadata["translation_notes"] || "",
          raw_response: metadata["raw_response"] || "",
          # Job descriptions specific data
          job_descriptions: is_job_descriptions,
          job_indices: metadata["job_indices"] || [],
          # Short reason for a failure (see AiTranslationJob.error_code_for)
          error_code: (metadata["error_code"] if translation.status == "failed"),
          # Include remaining counts so frontend can update after completion/failure
          remaining_summary: usage_limits.remaining_summary_translations,
          remaining_jobs: usage_limits.remaining_jobs_translations
        }

        # Parse jobs from english_text if this is a job descriptions translation
        if is_job_descriptions && translation.english_text.present?
          begin
            parsed = JSON.parse(translation.english_text)
            response_data[:jobs] = parsed["jobs"] || []
          rescue JSON::ParserError
            response_data[:jobs] = []
          end
        end

        render json: response_data
      else
        # Job might still be processing - return pending status
        render json: {
          job_id: job_id,
          status: "processing",
          message: "Translation is still processing..."
        }
      end
    rescue => e
      Rails.logger.error "Translation status API error: #{e.message}"
      render json: { error: "Failed to get translation status", message: e.message }, status: :internal_server_error
    end
  end

  def export_pdf
    begin
      Rails.logger.info "Export PDF request: direct_download=#{params[:direct_download]}"
      selected_template = AtsTemplatePdfService.normalize_template_key(params[:template])

      # Track PDF export event
      track_event("pdf_exported", { resume_id: params[:resume_id] })

      # Ensure the user is authenticated
      unless current_user
        Rails.logger.error "No current user found for PDF export"
        return render json: { error: "Authentication required" }, status: :unauthorized
      end

      # Create the directory for storing PDFs if it doesn't exist
      pdf_dir = Rails.root.join("tmp", "pdfs", "generated")
      FileUtils.mkdir_p(pdf_dir) unless File.directory?(pdf_dir)

      # If resume_id is provided, perform the job immediately
      if params[:resume_id].present?
        Rails.logger.info "Performing PDF generation job immediately: user_id=#{current_user&.id}, resume_id=#{params[:resume_id]}"

        # Track CV Builder usage (only for new generations, not re-downloads)
        unless params[:direct_download] == "true"
          current_user.cv_generations.create!(
            resume_id: params[:resume_id],
            status: "completed",
            ai_model: "cv_builder",
            metadata: { source: "cv_builder", pdf_generated: true }
          )
        end

        options = {
          "user_id" => current_user&.id,
          "resume_id" => params[:resume_id],
          "view_in_browser" => params[:view_in_browser] == "true",
          "resume_params" => request.post? ? resume_params.as_json : nil,
          "template" => selected_template
        }

        job = CvBuilderPdfJob.new
        result = job.perform(options)

        if result[:status] == "success" && result[:file_path].present? && File.exist?(result[:file_path])
          Rails.logger.info "PDF generation complete, sending file from: #{result[:file_path]}"
          return send_file result[:file_path],
            filename: result[:filename] || "resume.pdf",
            type: "application/pdf",
            disposition: "attachment"
        else
          Rails.logger.error "PDF generation failed: #{result[:message]}"
          return render json: { error: "PDF generation failed", message: result[:message] }, status: :internal_server_error
        end
      end

      # Handle direct download using token
      if params[:direct_download] == "true" && params[:token].present?
        Rails.logger.info "Processing direct download request"

        redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/1")
        redis_key = "cv_builder:pdf:#{current_user.id}:#{params[:token]}"
        pdf_path = redis.get(redis_key)

        if pdf_path.present? && File.exist?(pdf_path)
          filename = File.basename(pdf_path)
          return send_file pdf_path, filename: filename, type: "application/pdf", disposition: "attachment"
        end

        Rails.logger.error "PDF file not found for direct download token"
        return render json: { error: "PDF not found" }, status: :not_found
      end

      # If no valid parameters are provided, check for resume data in POST body
      if request.post? && params[:resume].present?
        Rails.logger.info "Processing PDF export from resume data in POST body"

        # First save the resume, then generate PDF
        resume_data = params[:resume]
        @resume = current_user.resumes.build(
          complete_name: resume_data[:complete_name],
          email: resume_data[:email],
          phone_number: resume_data[:phone_number],
          city: resume_data[:city],
          country: resume_data[:country],
          professional_summary: resume_data[:professional_summary],
          professional_summary_english: resume_data[:professional_summary_english]
        )

        if @resume.save
          # Build nested attributes
          build_nested_attributes(@resume, resume_data)

          # Track CV Builder usage
          current_user.cv_generations.create!(
            resume_id: @resume.id,
            status: "completed",
            ai_model: "cv_builder",
            metadata: { source: "cv_builder", pdf_generated: true }
          )

          # Generate PDF
          options = {
            "user_id" => current_user.id,
            "resume_id" => @resume.id,
            "view_in_browser" => params[:view_in_browser] == "true",
            "template" => selected_template
          }

          job = CvBuilderPdfJob.new
          result = job.perform(options)

          if result[:status] == "success" && result[:file_path].present? && File.exist?(result[:file_path])
            Rails.logger.info "PDF generation complete, sending file from: #{result[:file_path]}"
            return send_file result[:file_path],
              filename: result[:filename] || "resume.pdf",
              type: "application/pdf",
              disposition: "attachment"
          else
            Rails.logger.error "PDF generation failed: #{result[:message]}"
            return render json: { error: "PDF generation failed", message: result[:message] }, status: :internal_server_error
          end
        else
          Rails.logger.error "Resume save failed: #{@resume.errors.full_messages}"
          return render json: { error: "Resume validation failed", errors: @resume.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # If no valid parameters are provided, return an error
      Rails.logger.error "Invalid parameters for PDF export"
      render json: { error: "Invalid parameters" }, status: :bad_request
    rescue => e
      Rails.logger.error "Error with PDF export: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  def pdf_status
    job_id = params[:job_id]
    token = params[:token]
    resume_id = params[:resume_id]

    Rails.logger.info "Checking PDF status for job_id=#{job_id}, resume_id=#{resume_id}"

    if job_id.blank? && token.blank? && resume_id.blank?
      return render json: { error: "Either job_id, token, or resume_id is required" }, status: :bad_request
    end

    # Make sure we have a current user
    unless current_user
      Rails.logger.error "No current user found for PDF status check"
      return render json: { error: "Authentication required" }, status: :unauthorized
    end

    # Let the job handle status checking
    status_result = CvBuilderPdfJob.check_pdf_status(current_user.id, job_id, token, resume_id)

    Rails.logger.info "PDF status check result: #{status_result.inspect}"

    # Add more details to the response to help with debugging
    if status_result[:status] == "completed"
      Rails.logger.info "PDF is ready for download - download_url: #{status_result[:download_url]}"
    end

    render json: status_result
  end

  # Endpoint to get translation limit info (must be above private). `credits`
  # says, per kind, whether the next use is free, will use a credit, or is
  # blocked, so the page can warn "this will use 1 credit".
  def translation_limit
    credits = Billing::UsageGate.quote(current_user, %i[summary_translation jobs_translation])
    render json: usage_limits.as_json.merge(credits: credits, **credits_upsell)
  end

  private

  # resume_id comes from the request; only the user's own resumes may be named.
  def owned_resume_id
    return nil if params[:resume_id].blank?

    current_user.resumes.find(params[:resume_id]).id
  end

  def usage_limits
    current_user.usage_limits
  end

  LIMIT_MAX_METHODS = {
    summary_translation: :max_summary_translations,
    jobs_translation: :max_jobs_translations
  }.freeze

  # Free allowance used up and no credit to fall back on.
  def render_translation_limit(kind)
    max = usage_limits.public_send(LIMIT_MAX_METHODS.fetch(kind)) || "∞"
    variant = Billing.enabled_for?(current_user) ? "no_credits" : "limit_reached"
    render json: {
      error: t("ux_overage.translations.#{kind}.#{variant}", max: max),
      limit_reached: true,
      remaining: 0,
      **credits_upsell
    }, status: :too_many_requests
  end

  def charge_json(charge, kind)
    return { charged: "free" } unless charge == :credit

    { charged: "credit", credits_spent: Billing::UsageGate.cost(kind), credit_balance: current_user.credit_balance }
  end

  def projected_remaining(current_remaining)
    return nil if usage_limits.unlimited?

    [ current_remaining - 1, 0 ].max
  end

  # Build nested attributes for resume from POST data
  def build_nested_attributes(resume, resume_data)
    # Educations
    if resume_data[:educations_attributes].present?
      resume_data[:educations_attributes].each do |edu|
        edu = edu.is_a?(Array) ? edu.last : edu
        resume.educations.create(
          degree: edu[:degree],
          institution: edu[:institution],
          start_date: edu[:start_date],
          end_date: edu[:end_date],
          gpa: edu[:gpa],
          is_current: edu[:is_current]
        )
      end
    end

    # Work experiences
    if resume_data[:work_experiences_attributes].present?
      resume_data[:work_experiences_attributes].each do |exp|
        exp = exp.is_a?(Array) ? exp.last : exp
        resume.work_experiences.create(
          job_title: exp[:job_title],
          company: exp[:company],
          start_date: exp[:start_date],
          end_date: exp[:end_date],
          is_current: exp[:is_current],
          responsibilities: exp[:responsibilities]
        )
      end
    end

    # Skills
    if resume_data[:skills_attributes].present?
      resume_data[:skills_attributes].each do |skill|
        skill = skill.is_a?(Array) ? skill.last : skill
        resume.skills.create(
          category: skill[:category],
          skill_names: skill[:skill_names]
        )
      end
    end

    # Certifications
    if resume_data[:certifications_attributes].present?
      resume_data[:certifications_attributes].each do |cert|
        cert = cert.is_a?(Array) ? cert.last : cert
        resume.certifications.create(
          name: cert[:name],
          organization: cert[:organization],
          date: cert[:date]
        )
      end
    end

    # Languages
    if resume_data[:languages_attributes].present?
      resume_data[:languages_attributes].each do |lang|
        lang = lang.is_a?(Array) ? lang.last : lang
        resume.languages.create(
          language: lang[:language],
          proficiency: lang[:proficiency]
        )
      end
    end
  end

  # Private method for resume params handling
  def resume_params
    # Handle both direct resume params and nested translation params
    resume_data = if params[:resume].present?
      params[:resume]
    elsif params[:translation] && params[:translation][:resume].present?
      params[:translation][:resume]
    else
      {}
    end

    resume_data.permit(
      :complete_name, :email, :phone_number, :city, :country,
      :professional_summary, :professional_summary_english,
      educations_attributes: [ :degree, :institution, :start_date, :end_date, :gpa, :is_current ],
      work_experiences_attributes: [ :job_title, :company, :start_date, :end_date, :is_current, responsibilities: [] ],
      skills_attributes: [ :category, skill_names: [] ],
      certifications_attributes: [ :name, :organization, :date ],
      languages_attributes: [ :language, :proficiency ]
    )
  end
end
