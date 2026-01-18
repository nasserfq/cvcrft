class Api::TranslationsController < ApplicationController
  before_action :authenticate_user!

  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token

  # Global limit per user for all AI translations
  MAX_TRANSLATIONS_PER_USER = 5

  def translate_professional_summary
    begin
      # Check translation limit
      remaining = remaining_translations
      if remaining <= 0
        render json: {
          error: "لقد استخدمت جميع الترجمات المتاحة (#{MAX_TRANSLATIONS_PER_USER})",
          limit_reached: true,
          remaining: 0
        }, status: :too_many_requests
        return
      end

      # Always enqueue a new AI translation job for every request
      Rails.logger.info "[AI Translate] Request params: #{params.inspect}"

      user_id = current_user.id
      resume_id = params[:resume_id]
      arabic_text = params[:arabic_text]

      # Validate input
      if arabic_text.blank?
        render json: { error: "Arabic text is required" }, status: :unprocessable_entity
        return
      end

      # Generate a unique job ID first
      job_id = SecureRandom.hex(12)

      job = AiTranslationJob.perform_async(
        arabic_text,
        user_id,
        resume_id,
        {
          "temperature" => 0.7,
          "max_tokens" => 500,
          "professional_summary" => true,
          "job_id" => job_id
        }
      )

      Rails.logger.info "[AI Translate] Job enqueued: #{job}, job_id: #{job_id}"
      render json: {
        job_id: job_id,
        status: "queued",
        remaining: remaining - 1,
        message: "Translation job has been queued. Please poll for status."
      }
    rescue => e
      Rails.logger.error "[AI Translate] Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Translation failed", message: e.message }, status: :internal_server_error
    end
  end

  def translate_job_descriptions
    begin
      # Check translation limit
      remaining = remaining_translations
      if remaining <= 0
        render json: {
          error: "لقد استخدمت جميع الترجمات المتاحة (#{MAX_TRANSLATIONS_PER_USER})",
          limit_reached: true,
          remaining: 0
        }, status: :too_many_requests
        return
      end

      Rails.logger.info "[AI Translate Jobs] Request params: #{params.inspect}"

      user_id = current_user.id
      resume_id = params[:resume_id]
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

      job = AiTranslationJob.perform_async(
        combined_text,
        user_id,
        resume_id,
        {
          "temperature" => 0.7,
          "max_tokens" => 2000,
          "job_descriptions" => true,
          "job_id" => job_id,
          "job_indices" => valid_jobs.map { |j| j["index"] }
        }
      )

      Rails.logger.info "[AI Translate Jobs] Job enqueued: #{job}, job_id: #{job_id}"
      render json: {
        job_id: job_id,
        status: "queued",
        job_count: valid_jobs.size,
        remaining: remaining - 1,
        message: "Translation job has been queued for #{valid_jobs.size} job descriptions."
      }
    rescue => e
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
          job_indices: metadata["job_indices"] || []
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
      Rails.logger.info "Export PDF request: params=#{params.inspect}, direct_download=#{params[:direct_download]}, token=#{params[:token]}"

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

        options = {
          "user_id" => current_user&.id,
          "resume_id" => params[:resume_id],
          "view_in_browser" => params[:view_in_browser] == "true",
          "resume_params" => request.post? ? resume_params.as_json : nil,
          "callback_url" => params[:callback_url]
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
        Rails.logger.info "Processing direct download request with token: #{params[:token]}"

        redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/1")
        redis_key = "cv_builder:pdf:#{current_user.id}:#{params[:token]}"
        pdf_path = redis.get(redis_key)

        if pdf_path.present? && File.exist?(pdf_path)
          filename = File.basename(pdf_path)
          return send_file pdf_path, filename: filename, type: "application/pdf", disposition: "attachment"
        end

        Rails.logger.error "PDF file not found for token: #{params[:token]}"
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

          # Generate PDF
          options = {
            "user_id" => current_user.id,
            "resume_id" => @resume.id,
            "view_in_browser" => params[:view_in_browser] == "true"
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

    Rails.logger.info "Checking PDF status for job_id=#{job_id}, token=#{token}, resume_id=#{resume_id}"

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

  private

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

  # Calculate remaining translations for current user
  def remaining_translations
    used = current_user.ai_translations.count
    [ MAX_TRANSLATIONS_PER_USER - used, 0 ].max
  end

  # Endpoint to get translation limit info
  def translation_limit
    render json: {
      max: MAX_TRANSLATIONS_PER_USER,
      used: current_user.ai_translations.count,
      remaining: remaining_translations
    }
  end
end
