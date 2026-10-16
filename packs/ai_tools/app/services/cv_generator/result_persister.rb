module CvGenerator
  # Writes a parsed generation result: the summary, tokens and full structure
  # onto the CvGeneration, and the sections onto a newly created resume. The
  # resume is handed in (duck-typed), so this pack never names Resume here.
  class ResultPersister
    def initialize(cv_generation)
      @cv_generation = cv_generation
    end

    # Store only the professional summary in the main field, but the FULL
    # structure in metadata. `snapshot` is the source resume's ResumeSnapshot
    # hash, or nil for a new CV.
    def record!(result, snapshot:)
      # If we have an existing resume, use its data instead of AI-generated incomplete data
      if snapshot
        Rails.logger.info "Using existing resume data for skills, experience, etc."

        existing_data = snapshot
        Rails.logger.info "📊 Formatted skills: #{existing_data[:skills].inspect}"

        generated_data = {
          professional_summary: result[:professional_summary], # Only use AI-generated summary
          work_experiences: existing_data[:work_experiences],
          skills: existing_data[:skills],
          educations: existing_data[:educations],
          certifications: existing_data[:certifications],
          languages: existing_data[:languages]
        }

        Rails.logger.info "📦 Generated data skills to be stored: #{generated_data[:skills].inspect}"
      else
        # For new CVs, use all AI-generated data
        Rails.logger.info "Using AI-generated data for new CV"

        generated_data = {
          professional_summary: result[:professional_summary],
          work_experiences: result[:work_experiences],
          skills: result[:skills],
          educations: result[:educations],
          certifications: result[:certifications],
          languages: result[:languages]
        }
      end

      safe_meta = (@cv_generation.metadata || {})
      @cv_generation.update!(
        generated_content: result[:professional_summary],
        status: "processing",
        tokens_used: result[:tokens_used],
        metadata: safe_meta.merge({
          generated_data: generated_data,
          ats_optimization_notes: result[:ats_optimization_notes],
          generation_notes: result[:generation_notes],
          raw_response: result[:raw_response]
        })
      )
    end

    # Only for brand new, AI-only CVs; existing builder CVs are never mutated.
    # The sections come from JSON.parse, so their hashes are string-keyed;
    # indifferent access lets them be read the same way as symbol-keyed input.
    def populate_sections!(resume, result)
      result = result.with_indifferent_access
      populate_work_experiences(resume, result[:work_experiences]) if result[:work_experiences].present?
      populate_skills(resume, result[:skills]) if result[:skills].present?
      populate_educations(resume, result[:educations]) if result[:educations].present?
      populate_certifications(resume, result[:certifications]) if result[:certifications].present?
      populate_languages(resume, result[:languages]) if result[:languages].present?
    end

    private

    def populate_work_experiences(resume, work_experiences_data)
      return unless work_experiences_data.present?

      work_experiences_data.each do |exp_data|
        experience = resume.work_experiences.find_or_initialize_by(
          company: exp_data[:company],
          job_title: exp_data[:job_title],
          start_date: exp_data[:start_date]
        )

        experience.update!(
          end_date: exp_data[:end_date],
          responsibilities: Array(exp_data[:responsibilities])
        )
      end
    end

    def populate_skills(resume, skills_data)
      return unless skills_data.present?

      # Don't destroy existing skills, just add new ones if needed
      skills_data.each do |skill_group|
        category = skill_group[:category]
        names = if skill_group[:names].is_a?(Array)
          skill_group[:names]
        else
          skill_group[:names].to_s.split(",").map(&:strip)
        end

        next unless names.present?

        names.compact.each do |name|
          next if name.blank?
          # Use find_or_create_by to avoid duplicates
          existing_skill = resume.skills.find_by(category: category, name: name.strip)
          resume.skills.create!(category: category, name: name.strip, skill_names: [ name.strip ]) unless existing_skill
        end
      end
    end

    def populate_educations(resume, educations_data)
      return unless educations_data.present?

      educations_data.each do |edu_data|
        education = resume.educations.find_or_initialize_by(
          degree: edu_data[:degree],
          institution: edu_data[:institution]
        )

        education.update!(
          start_date: edu_data[:start_date],
          end_date: edu_data[:end_date],
          gpa: edu_data[:gpa]
        )
      end
    end

    def populate_certifications(resume, certifications_data)
      return unless certifications_data.present?

      certifications_data.each do |cert_data|
        certification = resume.certifications.find_or_initialize_by(
          name: cert_data[:name],
          organization: cert_data[:organization]
        )

        certification.update!(
          date: cert_data[:date]
        )
      end
    end

    def populate_languages(resume, languages_data)
      return unless languages_data.present?

      languages_data.each do |lang_data|
        language = resume.languages.find_or_initialize_by(
          language: lang_data[:language]
        )

        language.update!(
          proficiency: lang_data[:proficiency]
        )
      end
    end
  end
end
