# Persists builder form draft_data onto the resume record and associations
# so live PDF preview reflects unsaved step edits.
class ResumeDraftSync
  COLLECTION_FIELDS = %w[education work_experience skills certifications languages].freeze

  def self.sync!(resume, draft_data = nil)
    new(resume, draft_data).sync!
  end

  def initialize(resume, draft_data = nil)
    @resume = resume
    @draft_data = draft_data || resume.draft_data
  end

  def sync!
    data = normalized_draft_data
    return resume if data.blank?

    resume.skip_validations_for_pdf = true
    resume.transaction do
      resume.assign_attributes(
        complete_name: pick(data, :complete_name),
        email: pick(data, :email),
        phone_number: pick(data, :phone_number),
        city: pick(data, :city),
        country: pick(data, :country),
        professional_summary: pick(data, :professional_summary, :professional_summary_english),
        professional_summary_english: pick(data, :professional_summary_english, :professional_summary)
      )
      resume.save!(validate: false)

      sync_work_experiences(collection_for(data, :work_experience))
      sync_educations(collection_for(data, :education))
      sync_skills(collection_for(data, :skills))
      sync_certifications(collection_for(data, :certifications))
      sync_languages(collection_for(data, :languages))
    end

    resume.reload
  end

  private

  attr_reader :resume, :draft_data

  def normalized_draft_data
    return {} if draft_data.blank?

    draft_data.stringify_keys
  end

  def pick(data, *keys)
    keys.each do |key|
      value = data[key.to_s]
      return value if value.present?
    end
    nil
  end

  def collection_for(data, key)
    parse_collection(data[key.to_s])
  end

  def parse_collection(value)
    parsed =
      if value.is_a?(String)
        JSON.parse(value)
      else
        value
      end

    Array(parsed)
  rescue JSON::ParserError
    []
  end

  def meaningful_entry?(item, required_keys)
    return false unless item.is_a?(Hash)

    required_keys.all? { |key| item[key].to_s.strip.present? || item[key.to_s].to_s.strip.present? }
  end

  def read_value(item, key)
    item[key] || item[key.to_s]
  end

  def sync_work_experiences(items)
    resume.work_experiences.destroy_all

    items.each do |item|
      next unless meaningful_entry?(item, %w[job_title company start_date])

      responsibilities = Array(read_value(item, :responsibilities)).map(&:to_s).map(&:strip).reject(&:blank?)

      resume.work_experiences.create!(
        job_title: read_value(item, :job_title),
        company: read_value(item, :company),
        start_date: read_value(item, :start_date),
        end_date: read_value(item, :end_date),
        is_current: ActiveModel::Type::Boolean.new.cast(read_value(item, :is_current)),
        responsibilities: responsibilities
      )
    end
  end

  def sync_educations(items)
    resume.educations.destroy_all

    items.each do |item|
      next unless meaningful_entry?(item, %w[degree institution start_date])

      resume.educations.create!(
        degree: read_value(item, :degree),
        institution: read_value(item, :institution),
        start_date: read_value(item, :start_date),
        end_date: read_value(item, :end_date),
        gpa: read_value(item, :gpa),
        is_current: ActiveModel::Type::Boolean.new.cast(read_value(item, :is_current))
      )
    end
  end

  def sync_skills(items)
    resume.skills.destroy_all

    items.each do |item|
      category = read_value(item, :category).to_s.strip
      skill_names = Array(read_value(item, :skill_names)).map(&:to_s).map(&:strip).reject(&:blank?)
      next if category.blank? || skill_names.empty?

      resume.skills.create!(
        category: category,
        skill_names: skill_names
      )
    end
  end

  def sync_certifications(items)
    resume.certifications.destroy_all

    items.each do |item|
      next unless meaningful_entry?(item, %w[name organization])

      resume.certifications.create!(
        name: read_value(item, :name),
        organization: read_value(item, :organization),
        date: read_value(item, :date)
      )
    end
  end

  def sync_languages(items)
    resume.languages.destroy_all

    items.each do |item|
      next unless meaningful_entry?(item, %w[language proficiency])

      resume.languages.create!(
        language: read_value(item, :language),
        proficiency: read_value(item, :proficiency)
      )
    end
  end
end
