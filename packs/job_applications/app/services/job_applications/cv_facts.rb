module JobApplications
  # The CV as the matching prompt sees it, read only through ResumeBuilder::PublicApi.
  # No name, email or phone: nothing that identifies the user leaves the app.
  class CvFacts
    MAX_CHARS = 6_000

    attr_reader :user, :resume_id

    def initialize(user, resume_id)
      @user = user
      @resume_id = resume_id
    end

    def cv
      @cv ||= ResumeBuilder::PublicApi.read(user, resume_id)
    end

    def to_prompt
      facts = {
        "summary" => cv["professional_summary_english"].presence || cv["professional_summary"],
        "work_experience" => cv["work_experience"].map { |w| w.slice("job_title", "company", "start_date", "end_date", "is_current").merge("responsibilities" => Array(w["responsibilities"]).first(4)) },
        "education" => cv["education"].map { |e| e.slice("degree", "institution", "start_date", "end_date") },
        "skills" => cv["skills"].flat_map { |s| Array(s["skill_names"]) }.uniq,
        "certifications" => cv["certifications"].map { |c| c["name"] },
        "languages" => cv["languages"]
      }
      text = facts.to_json
      return text if text.size <= MAX_CHARS

      facts["work_experience"].each { |w| w.delete("responsibilities") }
      facts.to_json.first(MAX_CHARS)
    end
  end
end
