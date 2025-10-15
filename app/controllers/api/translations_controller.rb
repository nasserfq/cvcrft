class Api::TranslationsController < ApplicationController
  before_action :authenticate_user!

  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token

  def translate_professional_summary
    begin
      # Log the incoming parameters for debugging
      Rails.logger.info "Translation request params: #{params.inspect}"

      # Get user_id from params or use a default for now
      user_id = params[:user_id] || 1
      resume_id = params[:resume_id]

      Rails.logger.info "Using user_id: #{user_id}, resume_id: #{resume_id}"

      # Enqueue the translation job instead of calling the service directly
      job = AiTranslationJob.perform_async(
        params[:arabic_text],
        user_id,
        resume_id,
        {
          "temperature" => 0.7,
          "max_tokens" => 500,
          "professional_summary" => true
        }
      )

      Rails.logger.info "Translation job enqueued: #{job}"

      # Return job information for polling
      render json: {
        job_id: job,
        status: "queued",
        message: "Translation job has been queued. Please poll for status."
      }
    rescue => e
      Rails.logger.error "Translation API error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Translation failed", message: e.message }, status: :internal_server_error
    end
  end

  def translation_status
    begin
      # Get user_id from params or use a default for now
      user_id = params[:user_id] || 1

      # Find the latest translation for this user
      translation = AiTranslation.where(user_id: user_id)
                               .order(created_at: :desc)
                               .first

      if translation
        # Parse the metadata to get the structured translation data
        metadata = translation.metadata || {}

        render json: {
          id: translation.id,
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
          raw_response: metadata["raw_response"] || ""
        }
      else
        render json: { error: "Translation not found" }, status: :not_found
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
