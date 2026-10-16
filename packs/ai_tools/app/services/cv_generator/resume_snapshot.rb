module CvGenerator
  # The source resume as the plain hash the prompt, the parser and the stored
  # generated_data all use. Takes any resume-like object (duck-typed), so this
  # pack never names Resume here.
  class ResumeSnapshot
    def initialize(resume)
      @resume = resume
    end

    def to_h
      return {} unless @resume

      # Return structured data of existing resume
      {
        professional_summary: @resume.professional_summary,
        work_experiences: @resume.work_experiences.map { |exp|
          # Handle responsibilities based on how they're stored
          responsibilities = if exp.respond_to?(:responsibilities)
            if exp.responsibilities.is_a?(Array)
              exp.responsibilities
            elsif exp.responsibilities.is_a?(String)
              exp.responsibilities.split("\n").reject(&:empty?)
            else
              []
            end
          elsif exp.respond_to?(:description)
            exp.description.split("\n").map(&:strip).reject(&:empty?)
          else
            []
          end

          {
            job_title: exp.job_title,
            company: exp.company,
            start_date: exp.start_date,
            end_date: (exp.respond_to?(:is_current) && exp.is_current) ? "Present" : exp.end_date,
            responsibilities: responsibilities
          }
        },
        skills: @resume.skills.map { |skill|
          # Use skill_names array if available, otherwise fall back to name
          skill_list = if skill.skill_names.present?
            skill.skill_names
          elsif skill.name.present?
            [ skill.name ]
          else
            []
          end

          {
            category: skill.category || "Technical Skills",
            names: skill_list,
            details: skill_list.join(", ")  # Add details string for PDF generator
          }
        }.group_by { |s| s[:category] }.map { |category, skills|
          all_names = skills.flat_map { |s| s[:names] }.compact.reject(&:blank?)
          {
            category: category,
            names: all_names,
            details: all_names.join(", ")  # Convert array to comma-separated string
          }
        },
        educations: @resume.educations.map { |edu|
          education_data = {
            degree: edu.degree,
            institution: edu.institution,
            start_date: edu.start_date,
            end_date: edu.end_date
          }
          education_data[:gpa] = edu.gpa if edu.respond_to?(:gpa) && edu.gpa.present?
          education_data
        },
        certifications: @resume.certifications.map { |cert|
          {
            name: cert.name,
            organization: cert.organization,
            date: cert.date
          }
        },
        languages: @resume.languages.map { |lang|
          {
            language: lang.language,
            proficiency: lang.proficiency
          }
        }
      }
    end
  end
end
