# Removes duplicate unfinished draft resumes for a user.
# Empty step-1 drafts with no real content are collapsed to one per email.
# Other drafts are grouped by step, contact info, associations, and meaningful draft data.
class ResumeDraftDeduplicator
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    removed = 0

    grouped_drafts.each_value do |resumes|
      next if resumes.size <= 1

      keeper = resumes.max_by(&:updated_at)
      resumes.each do |resume|
        next if resume.id == keeper.id

        resume.destroy
        removed += 1
      end
    end

    removed
  end

  private

  attr_reader :user

  def grouped_drafts
    draft_resumes.group_by { |resume| signature_for(resume) }
  end

  def draft_resumes
    user.resumes.drafts.includes(
      :work_experiences,
      :educations,
      :skills,
      :certifications,
      :languages
    )
  end

  def signature_for(resume)
    if resume.empty_starter_draft?
      return [ :empty_starter, normalized(resume.email) ]
    end

    [
      resume.current_draft_step,
      normalized(resume.complete_name),
      normalized(resume.email),
      normalized(resume.phone_number),
      normalized(resume.city),
      normalized(resume.country),
      normalized(resume.professional_summary_english),
      normalized(resume.professional_summary),
      association_signature(resume),
      meaningful_draft_data_signature(resume.draft_data)
    ]
  end

  def association_signature(resume)
    [
      resume.work_experiences.size,
      resume.educations.size,
      resume.skills.size,
      resume.certifications.size,
      resume.languages.size
    ]
  end

  def meaningful_draft_data_signature(draft_data)
    return "" if draft_data.blank?

    %w[
      complete_name email phone_number city country
      professional_summary professional_summary_english
      education work_experience skills certifications languages
    ].map { |field| normalized_meaningful_value(draft_data[field]) }.join("|")
  end

  def normalized_meaningful_value(value)
    return "" if value.blank?

    if value.is_a?(String) && value.strip.start_with?("[", "{")
      parsed = JSON.parse(value)
      return "" if collection_effectively_empty?(parsed)

      normalized(parsed.to_json)
    else
      normalized(value)
    end
  rescue JSON::ParserError
    normalized(value)
  end

  def collection_effectively_empty?(value)
    return true if value.blank?

    Array(value).all? do |item|
      next true unless item.is_a?(Hash)

      item.values.all? do |entry|
        entry.blank? || (entry.is_a?(Array) && entry.all?(&:blank?))
      end
    end
  end

  def normalized(value)
    value.to_s.strip.downcase
  end
end
