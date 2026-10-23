class CvImportsController < ApplicationController
  include CreditsUpsell

  before_action :authenticate_user!
  before_action :set_cv_import, only: [ :status, :show ]

  # POST /cv-import
  # Accepts PDF file upload, extracts text, validates language, and queues for AI processing
  def create
    # Check if file was uploaded
    unless params[:pdf_file].present?
      return render json: {
        success: false,
        error: t("ux_i18n2.cv_imports.pdf_required")
      }, status: :unprocessable_entity
    end

    pdf_file = params[:pdf_file]

    # Validate file type
    unless pdf_file.content_type == "application/pdf"
      return render json: {
        success: false,
        error: t("ux_i18n2.cv_imports.pdf_only")
      }, status: :unprocessable_entity
    end

    # Validate file size (max 10MB)
    if pdf_file.size > 10.megabytes
      return render json: {
        success: false,
        error: t("ux_i18n2.cv_imports.file_too_large")
      }, status: :unprocessable_entity
    end

    begin
      # Parse PDF to extract text and detect language
      parser = CvPdfImportService.new(pdf_file.path)
      result = parser.parse

      # Check if content is primarily Arabic
      if result[:language] == "ar"
        return render json: {
          success: false,
          error: t("ux_i18n2.cv_imports.arabic_content"),
          error_type: "arabic_content"
        }, status: :unprocessable_entity
      end

      # Create the import record
      @cv_import = CvImport.new(
        user: current_user,
        extracted_text: result[:text],
        detected_language: result[:language],
        original_filename: pdf_file.original_filename
      )

      # Free allowance first, then credits (Billing::UsageGate::COSTS) while billing is on
      charge_key = SecureRandom.uuid
      charge = Billing::UsageGate.allow!(current_user, :document_ai, key: charge_key)
      if charge == :blocked
        return render json: { success: false, error: t("ux_i18n2.cv_imports.limit_reached"), limit_reached: true, **credits_upsell }, status: :too_many_requests
      end

      if @cv_import.save
        # Queue the background job for AI processing
        CvImportJob.perform_async(@cv_import.id, *(charge_key if charge == :credit))

        render json: {
          success: true,
          id: @cv_import.id,
          status_url: cv_import_status_path(@cv_import, format: :json),
          message: t("ux_i18n2.cv_imports.analyzing")
        }
      else
        refund_import(charge, charge_key)
        render json: {
          success: false,
          error: @cv_import.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end

    rescue CvPdfImportService::CorruptedFileError => e
      render json: {
        success: false,
        error: e.message,
        error_type: "corrupted_file"
      }, status: :unprocessable_entity

    rescue CvPdfImportService::ArabicContentError => e
      render json: {
        success: false,
        error: e.message,
        error_type: "arabic_content"
      }, status: :unprocessable_entity

    rescue CvPdfImportService::CvPdfParseError => e
      render json: {
        success: false,
        error: t("ux_i18n2.cv_imports.read_failed", error: e.message),
        error_type: "parse_error"
      }, status: :unprocessable_entity

    rescue => e
      refund_import(charge, charge_key)
      Rails.logger.error "[CvImport] Unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      render json: {
        success: false,
        error: t("ux_i18n2.cv_imports.unexpected_error"),
        error_type: "unknown"
      }, status: :internal_server_error
    end
  end

  # GET /cv-import/:id/status
  # Returns current status of import processing
  def status
    render json: {
      status: @cv_import.status,
      error_message: @cv_import.error_message,
      completed: @cv_import.completed?,
      failed: @cv_import.failed?,
      processing: @cv_import.processing?,
      parsed_data: @cv_import.completed? ? @cv_import.parsed_data : nil
    }
  end

  # GET /cv-import/:id
  # Returns the parsed data for completed imports
  def show
    unless @cv_import.completed?
      return render json: {
        success: false,
        error: "Import not yet completed",
        status: @cv_import.status
      }, status: :unprocessable_entity
    end

    render json: {
      success: true,
      parsed_data: @cv_import.parsed_data
    }
  end

  private

  # Gives the credit back when the import it paid for didn't start.
  def refund_import(charge, key)
    Billing::UsageGate.refund!(current_user, :document_ai, key: key) if charge == :credit
  end

  def set_cv_import
    @cv_import = current_user.cv_imports.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Import not found" }, status: :not_found
  end
end
