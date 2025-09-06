class Api::TranslationsController < ApplicationController
  # Remove authentication for now - you can add it back when you implement user authentication
  # before_action :authenticate_user!
  
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
      # Get user_id from params
      user_id = params[:user_id] || 1
      resume_id = params[:resume_id]

      resume = nil

      if resume_id.present?
        # GET request - use existing resume from database
        resume = Resume.find(resume_id)
        Rails.logger.info "Using existing resume with ID: #{resume_id}"
      elsif request.post? && params[:resume].present?
        # POST request - create temporary resume from form data
        Rails.logger.info "Creating temporary resume from form data"

        # Create a temporary resume object without saving to database
        resume = Resume.new(resume_params)

        # Build associated objects from form data
        resume_data = if params[:resume].present?
          params[:resume]
        elsif params[:translation] && params[:translation][:resume].present?
          params[:translation][:resume]
        else
          {}
        end

        if resume_data[:educations_attributes].present?
          resume_data[:educations_attributes].each do |edu_attrs|
            resume.educations.build(edu_attrs.permit(:degree, :institution, :start_date, :end_date, :gpa, :is_current))
          end
        end

        if resume_data[:work_experiences_attributes].present?
          resume_data[:work_experiences_attributes].each do |work_attrs|
            resume.work_experiences.build(work_attrs.permit(:job_title, :company, :start_date, :end_date, :is_current, responsibilities: []))
          end
        end

        if resume_data[:skills_attributes].present?
          resume_data[:skills_attributes].each do |skill_attrs|
            resume.skills.build(skill_attrs.permit(:category, skill_names: []))
          end
        end

        if resume_data[:certifications_attributes].present?
          resume_data[:certifications_attributes].each do |cert_attrs|
            resume.certifications.build(cert_attrs.permit(:name, :organization, :date))
          end
        end

        if resume_data[:languages_attributes].present?
          resume_data[:languages_attributes].each do |lang_attrs|
            resume.languages.build(lang_attrs.permit(:language, :proficiency))
          end
        end
      else
        render json: { error: "Resume ID or form data is required" }, status: :bad_request
        return
      end

      # Generate HTML content using the service
      pdf_service = ResumePdfService.new(resume)
      html_content = pdf_service.generate

      Rails.logger.info "Generated HTML length: #{html_content.length}"

      # Generate PDF using WickedPDF with ATS-friendly options
      Rails.logger.info "About to generate PDF with WickedPDF"
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        page_size: "A4",
        orientation: "Portrait",
        margin: {
          top: 0.75,
          bottom: 0.75,
          left: 0.75,
          right: 0.75
        },
        encoding: "UTF-8",
        print_media_type: true,
        disable_smart_shrinking: true,
        no_stop_slow_scripts: true,
        enable_forms: false,
        disable_external_links: true,
        disable_internal_links: true
      )

      Rails.logger.info "Generated PDF size: #{pdf.bytesize}"
      Rails.logger.info "PDF starts with: #{pdf[0..50]}"

      # Send the PDF as a download
      filename = resume.complete_name.present? ? "#{resume.complete_name.parameterize}_resume.pdf" : "resume.pdf"
      
      # Set proper headers
      response.headers['Content-Type'] = 'application/pdf'
      response.headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
      
      send_data pdf,
        filename: filename,
        type: "application/pdf",
        disposition: "attachment"
    rescue => e
      Rails.logger.error "PDF export error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      render json: { error: "Failed to export PDF", message: e.message }, status: :internal_server_error
    end
  end

  private

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
