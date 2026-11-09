require "prawn"
require "prawn/table"

class CvBuilderPdfJob
  include Sidekiq::Job

  sidekiq_options retry: 3, backtrace: true, queue: :cv_builder

  # Renders a resume (resume_id, or unsaved resume_params) to a PDF file and
  # returns { status: "success", file_path:, filename: } or
  # { status: "error", message: }. Api::TranslationsController#export_pdf
  # calls it inline and sends the file.
  def perform(options)
    Rails.logger.info "=== CV BUILDER PDF JOB STARTED ==="

    # Extract parameters
    resume_id = options["resume_id"]
    user_id = options["user_id"]
    resume_params = options["resume_params"]
    template = options["template"]

    Rails.logger.info "Processing PDF job with: user_id=#{user_id}, resume_id=#{resume_id || 'none'}"

    begin
      # Fetch or create the resume
      resume = fetch_or_create_resume(resume_id, resume_params, user_id)

      # Generate the PDF
      pdf_result = generate_pdf(resume, template)

      Rails.logger.info "=== CV BUILDER PDF JOB COMPLETED ==="
      { status: "success", file_path: pdf_result[:path], filename: pdf_result[:filename] }
    rescue => e
      Rails.logger.error "Error in CV Builder PDF Job: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { status: "error", message: e.message }
    end
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

  def generate_pdf(resume, template = nil)
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
end
