module JobApplications
  # The CV, as the AI prompts and the extension see it. Read only through ResumeBuilder::PublicApi.
  class CvFacts
    MAX_CHARS = 6_000

    attr_reader :user, :resume_id, :preference

    def initialize(user, resume_id, preference: nil)
      @user = user
      @resume_id = resume_id
      @preference = preference
    end

    def cv
      @cv ||= ResumeBuilder::PublicApi.read(user, resume_id)
    end

    # What a fit score or an answer may rest on; contact details only when asked for.
    def to_prompt(contact: false)
      facts = {
        "summary" => cv["professional_summary_english"].presence || cv["professional_summary"],
        "work_experience" => cv["work_experience"].map { |w| w.slice("job_title", "company", "start_date", "end_date", "is_current").merge("responsibilities" => Array(w["responsibilities"]).first(4)) },
        "education" => cv["education"].map { |e| e.slice("degree", "institution", "start_date", "end_date") },
        "skills" => cv["skills"].flat_map { |s| Array(s["skill_names"]) }.uniq,
        "certifications" => cv["certifications"].map { |c| c["name"] },
        "languages" => cv["languages"]
      }
      facts = contact_details.merge(facts) if contact
      text = facts.to_json
      return text if text.size <= MAX_CHARS

      facts["work_experience"].each { |w| w.delete("responsibilities") }
      facts.to_json.first(MAX_CHARS)
    end

    def contact_details
      first, last = split_name(cv["complete_name"])
      {
        "first_name" => first, "last_name" => last, "full_name" => cv["complete_name"].to_s.squish.presence,
        "email" => cv["email"].presence || user.email, "phone" => cv["phone_number"].presence,
        "city" => cv["city"].presence, "country" => cv["country"].presence,
        "linkedin_url" => preference&.linkedin_url.presence
      }
    end

    # GET /profile for the extension.
    def profile
      contact_details.merge(
        "resume_id" => resume_id,
        "summary" => cv["professional_summary_english"].presence || cv["professional_summary"],
        "work_experience" => cv["work_experience"].map { |w| w.slice("job_title", "company", "start_date", "end_date", "is_current") },
        "education" => cv["education"].map { |e| e.slice("degree", "institution", "start_date", "end_date") },
        "skills" => cv["skills"].flat_map { |s| Array(s["skill_names"]) }.uniq,
        "languages" => cv["languages"].map { |l| l.slice("language", "proficiency") }
      )
    end

    private

    # The first token is the first name, the rest the last name.
    def split_name(name)
      parts = name.to_s.squish.split(" ")
      [ parts.first, parts.drop(1).join(" ").presence ]
    end
  end
end
