require "prawn"
require "prawn/table"

class CvBuilderPdfJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true, queue: :cv_builder

  # Job will be called with resume_id or resume_params
  def perform(options)
    Rails.logger.info "=== CV BUILDER PDF JOB STARTED ==="

    # Extract parameters
    resume_id = options["resume_id"]
    user_id = options["user_id"]
    resume_params = options["resume_params"]
    job_token = options["job_token"]
    direct_download = options["direct_download"] || false
    template = options["template"]

    Rails.logger.info "Processing PDF job with: user_id=#{user_id}, resume_id=#{resume_id || 'none'}, job_token=#{job_token}"

    begin
      # Fetch or create the resume
      resume = fetch_or_create_resume(resume_id, resume_params, user_id)

      # Generate the PDF
      pdf_result = generate_pdf(resume, job_token, template)

      # Store the PDF in Redis
      store_pdf_in_redis(user_id, job_token, pdf_result[:path])

      Rails.logger.info "=== CV BUILDER PDF JOB COMPLETED ==="
      { status: "success", file_path: pdf_result[:path], filename: pdf_result[:filename] }
    rescue => e
      Rails.logger.error "Error in CV Builder PDF Job: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { status: "error", message: e.message }
    end
  end

  # Class method to schedule PDF generation
  def self.schedule_pdf_generation(user_id, resume_id, view_in_browser, resume_params = nil)
    Rails.logger.info "Scheduling PDF generation with params: user_id=#{user_id}, resume_id=#{resume_id}, view_in_browser=#{view_in_browser}"

    # Build options for the job
    options = {
      "user_id" => user_id,
      "resume_id" => resume_id,
      "view_in_browser" => view_in_browser,
      "resume_params" => resume_params
    }

    # Enqueue the job
    perform_async(options)
  rescue => e
    Rails.logger.error "Error scheduling PDF generation: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Status for the GET /api/pdf_status poller. store_pdf_in_redis keys the
  # generated path by job token, so the token is what locates a finished PDF;
  # resume_id is accepted because the endpoint allows it, but cannot locate one.
  def self.check_pdf_status(user_id, job_id, token, _resume_id = nil)
    key_token = token.presence || job_id.presence
    return { status: "failed", message: "A job token is required to locate the PDF" } if key_token.blank?

    redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/1")
    pdf_path = redis.get("cv_builder:pdf:#{user_id}:#{key_token}")

    if pdf_path.present? && File.exist?(pdf_path)
      { status: "completed",
        download_url: Rails.application.routes.url_helpers.api_export_pdf_translations_path(direct_download: true, token: key_token) }
    else
      { status: "processing" }
    end
  rescue => e
    Rails.logger.error "Error checking PDF status: #{e.message}"
    { status: "failed", message: e.message }
  end

  private

  def fetch_or_create_resume(resume_id, resume_params, user_id)
    if resume_id.present?
      Resume.find_by(id: resume_id).tap do |resume|
        raise "Resume not found" unless resume&.user_id == user_id
      end
    elsif resume_params.present?
      Resume.new(resume_params.merge(user_id: user_id))
    else
      raise "No resume ID or parameters provided"
    end
  end

  def generate_pdf(resume, job_token, template = nil)
    Rails.logger.info "Generating PDF for resume ID: #{resume.id}"

    # Always use the latest AI summary for PDF generation and persist it
    summary_to_use = ProfessionalSummaryText.normalize(
      resume.professional_summary_english.presence || resume.professional_summary
    )
    if summary_to_use.present? && resume.respond_to?(:persisted?) && resume.persisted?
      resume.update_column(:professional_summary_english, summary_to_use)
      Rails.logger.info "Ensured resume##{resume.id} professional_summary_english is up-to-date for PDF preview"
    end

    # Use template-based generator service
    data = {
      professional_summary: summary_to_use,
      educations: resume.educations.map { |e| { degree: e.degree, institution: e.institution, start_date: e.start_date, end_date: (e.respond_to?(:is_current) && e.is_current) ? "Present" : e.end_date, gpa: e.gpa } },
      work_experiences: resume.work_experiences.map { |we| { job_title: we.job_title, company: we.company, start_date: we.start_date, end_date: (we.respond_to?(:is_current) && we.is_current) ? "Present" : we.end_date, responsibilities: we.responsibilities } },
      skills: resume.skills.map { |s| { category: s.category, details: s.skill_names.join(", ") } },
      certifications: resume.certifications.map { |c| { name: c.name, organization: c.organization, date: c.date } },
      languages: resume.languages.map { |l| { language: l.language, proficiency: l.proficiency } }
    }

    pdf_result = AtsTemplatePdfService.generate_pdf(resume, data, template: template)
    Rails.logger.info "PDF generated at #{pdf_result[:path]}"

    pdf_result
  end

  def store_pdf_in_redis(user_id, job_token, pdf_path)
    redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379/1")
    redis_key = "cv_builder:pdf:#{user_id}:#{job_token}"
    redis.setex(redis_key, 24.hours.to_i, pdf_path)
    Rails.logger.info "Stored PDF in Redis with key: #{redis_key}"
  end
end
