class ResumePdfService
  def self.generate_pdf(resume, options = {})
    # Build educations with fallback to draft data if needed
    educations_data = resume.educations.map { |e| {
      degree: e.degree,
      institution: e.institution,
      start_date: e.start_date,
      end_date: e.end_date
    } }

    if educations_data.blank?
      draft = (resume.respond_to?(:resume_data) ? resume.resume_data : (resume.respond_to?(:draft_data) ? resume.draft_data : {})) || {}
      raw_edu = draft["education"] || draft[:education] || []
      educations_data = Array(raw_edu).map do |ed|
        h = ed.is_a?(Hash) ? ed : {}
        # Normalize possible keys from the builder UI
        degree = h[:degree] || h["degree"] || h[:qualification] || h["qualification"]
        institution = h[:institution] || h["institution"] || h[:school] || h["school"] || h[:university] || h["university"]
        start_date = h[:start_date] || h["start_date"] || h[:from] || h["from"]
        end_date = h[:end_date] || h["end_date"] || h[:to] || h["to"]
        { degree: degree, institution: institution, start_date: start_date, end_date: end_date }
      end
    end

    AtsTemplatePdfService.generate_pdf(resume, {
      professional_summary: resume.professional_summary,
      work_experiences: resume.work_experiences.map(&:attributes),
      # Build skills details from stored structure (skill_names array or legacy fields)
      skills: resume.skills.map do |s|
        details = if s.respond_to?(:skill_names) && s.skill_names.present?
          Array(s.skill_names).join(", ")
        else
          s.respond_to?(:display_name) ? s.display_name : [ s.name, s.level ].compact.join(" - ")
        end
        { category: s.category, details: details }
      end,
      # Use symbol keys for educations to match AtsPdfGenerator expectations
      educations: educations_data,
      certifications: resume.certifications.map { |c| {
        name: c.name,
        organization: c.organization,
        date: c.date
      } },
      languages: resume.languages.map { |l| { language: l.language, proficiency: l.proficiency } }
    }, template: options[:template])
  end
end
