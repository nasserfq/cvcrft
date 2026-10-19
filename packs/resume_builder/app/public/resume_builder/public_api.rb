# The only way other packs reach resume_builder. Resumes go in and out as the
# draft hash ResumeDraftSync accepts, so callers and the builder share one shape.
module ResumeBuilder
  module PublicApi
    HEADER_FIELDS = %w[complete_name email phone_number city country professional_summary professional_summary_english].freeze
    FIELDS = {
      "work_experience" => %w[job_title company start_date end_date is_current responsibilities],
      "education" => %w[degree institution start_date end_date gpa is_current],
      "skills" => %w[category skill_names],
      "certifications" => %w[name organization date],
      "languages" => %w[language proficiency]
    }.freeze
    # Entries missing any of these are skipped by ResumeDraftSync.
    REQUIRED = {
      "work_experience" => %w[job_title company start_date],
      "education" => %w[degree institution start_date],
      "skills" => %w[category skill_names],
      "certifications" => %w[name organization],
      "languages" => %w[language proficiency]
    }.freeze

    module_function

    # Newest first, for pickers outside the builder; only the user's own resumes.
    def list(user)
      user.resumes.order(updated_at: :desc).map do |resume|
        { "id" => resume.id, "title" => resume.title.presence || resume.complete_name, "updated_at" => resume.updated_at }
      end
    end

    # Newest finished (non-draft) resume, as {"id"=>..., "title"=>..., "updated_at"=>...}, or nil.
    def latest_complete(user)
      resume = user.resumes.not_drafts.order(updated_at: :desc, id: :desc).first
      resume && { "id" => resume.id, "title" => resume.title.presence || resume.complete_name, "updated_at" => resume.updated_at }
    end

    # {filename: "Name_CV.pdf", data: "<binary>"} for one of the user's non-draft resumes.
    # ResumePdfService.generate_pdf returns either the bytes or {path:}.
    def pdf(user, resume_id)
      resume = user.resumes.not_drafts.find(resume_id)
      result = ResumePdfService.generate_pdf(resume)
      data = result.is_a?(Hash) ? File.binread((result[:path] || result["path"]).to_s) : result.to_s
      name = (resume.complete_name.presence || resume.title.presence || "resume").gsub(/[^\p{L}\p{N}]+/, "_").gsub(/\A_+|_+\z/, "")
      { filename: "#{name.presence || 'resume'}_CV.pdf", data: data.b }
    end

    def read(user, resume_id)
      resume = user.resumes.find(resume_id)

      resume.attributes.slice(*HEADER_FIELDS).merge(
        "work_experience" => resume.work_experiences.order(:id).map { |w|
          w.attributes.slice(*FIELDS["work_experience"])
            .merge("responsibilities" => parse_responsibilities(w.responsibilities))
        },
        "education" => resume.educations.order(:id).map { |e|
          e.attributes.slice(*FIELDS["education"])
        },
        "skills" => resume.skills.order(:id).map { |s| { "category" => s.category, "skill_names" => Array(s.skill_names) } },
        "certifications" => resume.certifications.order(:id).map { |c| c.attributes.slice(*FIELDS["certifications"]) },
        "languages" => resume.languages.order(:id).map { |l| l.attributes.slice(*FIELDS["languages"]) }
      )
    end

    def create_from_draft(user, draft)
      d = draft.stringify_keys
      # Created as a draft so the PDF job fires once, on the final update.
      resume = user.resumes.create!(
        d.slice(*%w[complete_name email phone_number city country]).merge(is_draft: true, source: "coach")
      )
      ResumeDraftSync.sync!(resume, d)
      resume.update!(is_draft: false)
      resume
    end

    # sync! stores the Array's to_s in a text column; same parse as AtsPdfGenerator.
    def parse_responsibilities(raw)
      return Array(raw) unless raw.is_a?(String)

      JSON.parse(raw)
    rescue JSON::ParserError
      raw.split("\n").map(&:strip).reject(&:blank?)
    end
  end
end
