class CvAnalysesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_cv_analysis, only: [ :show, :status ]

  # GET /cv-analysis
  def new
    @cv_analysis = CvAnalysis.new
    track_event("cv_analysis_page_viewed")
  end

  # POST /cv-analysis
  def create
    track_event("cv_analysis_upload_started")

    unless params[:pdf_file].present?
      track_event("cv_analysis_upload_failed", { error: "no_file" })
      respond_to do |format|
        format.html do
          flash[:alert] = "الرجاء رفع ملف PDF"
          redirect_to cv_analysis_path
        end
        format.json { render json: { success: false, error: "الرجاء رفع ملف PDF" }, status: :unprocessable_entity }
      end
      return
    end

    begin
      # Parse PDF to extract text
      pdf_file = params[:pdf_file]
      parser = LinkedinPdfParserService.new(pdf_file.path)
      extracted_text = parser.parse

      if extracted_text.blank?
        respond_to do |format|
          format.html do
            flash[:alert] = "لم نتمكن من استخراج نص من الملف"
            redirect_to cv_analysis_path
          end
          format.json { render json: { success: false, error: "لم نتمكن من استخراج نص من الملف" }, status: :unprocessable_entity }
        end
        return
      end

      # Create the analysis record
      @cv_analysis = current_user.cv_analyses.create!(
        original_filename: pdf_file.original_filename,
        extracted_text: extracted_text,
        target_job: params[:target_job].presence,
        target_industry: params[:target_industry].presence,
        language: params[:language].presence || "ar",
        status: "pending"
      )

      # Queue the analysis job
      CvAnalysisJob.perform_async(@cv_analysis.id)

      track_event("cv_analysis_upload_success", {
        analysis_id: @cv_analysis.id,
        language: @cv_analysis.language,
        has_target_job: params[:target_job].present?,
        has_target_industry: params[:target_industry].present?
      })

      respond_to do |format|
        format.html { redirect_to cv_analysis_show_path(@cv_analysis) }
        format.json do
          render json: {
            success: true,
            analysis_id: @cv_analysis.id,
            status_url: cv_analysis_status_path(@cv_analysis, format: :json)
          }
        end
      end
    rescue PDF::Reader::MalformedPDFError => e
      Rails.logger.error "PDF parsing error: #{e.message}"
      respond_to do |format|
        format.html do
          flash[:alert] = "الملف تالف أو غير صالح"
          redirect_to cv_analysis_path
        end
        format.json { render json: { success: false, error: "الملف تالف أو غير صالح" }, status: :unprocessable_entity }
      end
    rescue => e
      Rails.logger.error "CV Analysis creation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html do
          flash[:alert] = "حدث خطأ أثناء معالجة الملف"
          redirect_to cv_analysis_path
        end
        format.json { render json: { success: false, error: "حدث خطأ أثناء معالجة الملف" }, status: :unprocessable_entity }
      end
    end
  end

  # GET /cv-analysis/:id
  def show
    unless @cv_analysis.completed?
      # If not completed, show the status/processing page
      render :processing
      nil
    else
      track_event("cv_analysis_results_viewed", {
        analysis_id: @cv_analysis.id,
        overall_score: @cv_analysis.overall_score
      })
    end
  end

  # GET /cv-analysis/:id/status
  def status
    status_json = {
      id: @cv_analysis.id,
      status: @cv_analysis.status,
      completed: @cv_analysis.completed?,
      failed: @cv_analysis.failed?,
      error_message: @cv_analysis.error_message,
      redirect_url: @cv_analysis.completed? ? cv_analysis_show_path(@cv_analysis) : nil
    }

    respond_to do |format|
      format.json { render json: status_json }
      format.html { redirect_to cv_analysis_show_path(@cv_analysis) }
      format.any { render json: status_json }
    end
  end

  private

  def set_cv_analysis
    @cv_analysis = current_user.cv_analyses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to cv_analysis_path, alert: "التحليل غير موجود"
  end
end
