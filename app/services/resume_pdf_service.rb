class ResumePdfService
  def self.generate_pdf(resume, options = {})
    AtsPdfGenerator.generate_pdf(resume, {
      professional_summary: resume.professional_summary,
      work_experiences: resume.work_experiences.map(&:attributes),
      skills: resume.skills.map { |s| { category: s.category, details: s.details } },
      educations: resume.educations.map(&:attributes),
      certifications: resume.certifications.map { |c| {
        name: c.name,
        organization: c.organization,
        date: c.date
      } },
      languages: resume.languages.map { |l| { language: l.language, proficiency: l.proficiency } }
    })
  end
end
