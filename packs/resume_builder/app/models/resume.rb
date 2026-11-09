class Resume < ApplicationRecord
  belongs_to :user
  has_many :work_experiences, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :languages, dependent: :destroy
  has_many :ai_translations, dependent: :destroy
  has_many :cv_generations, dependent: :destroy
  has_one :linkedin_import
  has_many :linkedin_imports, dependent: :nullify
  has_many :cv_imports, dependent: :nullify

  # Find linkedin import for editing - either directly associated or find by user
  def linkedin_import_for_edit
    linkedin_import || (source == "linkedin" ? user.linkedin_imports.completed.order(created_at: :desc).first : nil)
  end

  # PDFs are rendered on request (Api::TranslationsController#export_pdf ->
  # CvBuilderPdfJob#perform), never on save. Lets that path skip validations.
  attr_accessor :skip_validations_for_pdf

  # Accept nested attributes
  accepts_nested_attributes_for :work_experiences, allow_destroy: true
  accepts_nested_attributes_for :skills, allow_destroy: true
  accepts_nested_attributes_for :educations, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :certifications, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :languages, allow_destroy: true, reject_if: :all_blank

  # Validations for new fields - with conditional bypass for PDF generation
  validates :user_id, presence: true, unless: :skip_validations_for_pdf
  validates :complete_name, presence: true, length: { minimum: 2, maximum: 100 }, unless: :skip_validations_for_pdf
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, unless: :skip_validations_for_pdf
  validates :phone_number, length: { maximum: 50 }, allow_blank: true
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :country, length: { maximum: 100 }, allow_blank: true
  # Professional summary validation - minimal for CV Builder
  validates :professional_summary, length: { maximum: 1000 }, allow_blank: true
  validates :professional_summary_english, length: { maximum: 1000 }, allow_blank: true
  # The summary may be typed in Arabic, but the CV is English only and the PDF
  # fonts cannot draw Arabic: the English copy must come from the AI translation.
  validates :professional_summary_english, format: { without: ArabicText::PATTERN, message: "must be translated to English with AI" },
                                           if: :professional_summary_english_changed?, unless: :skip_validations_for_pdf

  # Legacy validations (keeping for backward compatibility)
  validates :title, length: { minimum: 3, maximum: 100 }, allow_blank: true
  validates :target_position, length: { minimum: 3, maximum: 100 }, allow_blank: true
  # No minimum: the builder accepts a 5-character summary, and the AI
  # translation copies its English text here, so a short one must still save.
  validates :summary, length: { maximum: 1000 }, allow_blank: true

  # ATS optimization fields
  validates :ats_score, numericality: { greater_than: 0, less_than: 101 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_ats_score, -> { order(ats_score: :desc) }
  scope :drafts, -> { where(is_draft: true) }
  scope :not_drafts, -> { where(is_draft: false) }

  # Methods
  def draft?
    is_draft?
  end

  def current_draft_step
    (draft_data&.dig("current_step") || draft_data&.dig("step") || 1).to_i
  end

  def empty_starter_draft?
    return false unless draft?

    current_draft_step <= 1 && !has_meaningful_draft_content?
  end

  def has_meaningful_draft_content?
    return true if work_experiences.exists?
    return true if educations.exists?
    return true if skills.exists?
    return true if certifications.exists?
    return true if languages.exists?
    return true if professional_summary_english.present?
    return true if professional_summary.present?

    draft_data_has_meaningful_content?
  end

  # Only drafts reopen through resume_draft; a finished resume is edited in place.
  def can_be_resumed?
    draft?
  end

  def resume_data
    draft_data || {}
  end

  def load_draft_data
    return {} unless draft_data.present?

    data = draft_data.dup
    # Parse JSON strings back to objects
    %w[education work_experience skills certifications languages].each do |field|
      if data[field].is_a?(String)
        begin
          data[field] = JSON.parse(data[field])
        rescue JSON::ParserError
          data[field] = []
        end
      end
    end
    data
  end

  def draft_data_has_meaningful_content?
    return false if draft_data.blank?

    %w[education work_experience skills certifications languages].any? do |field|
      draft_collection_has_content?(draft_data[field])
    end
  end

  def draft_collection_has_content?(value)
    parsed = parse_draft_json(value)
    return false if parsed.blank?

    Array(parsed).any? { |item| draft_item_has_content?(item) }
  rescue JSON::ParserError
    false
  end

  def draft_item_has_content?(item)
    return false unless item.is_a?(Hash)

    item.any? { |_key, entry| draft_field_has_content?(entry) }
  end

  def draft_field_has_content?(entry)
    case entry
    when Array
      entry.any? { |nested| draft_field_has_content?(nested) }
    when TrueClass, FalseClass
      false
    else
      entry.present? && entry.to_s.strip.present?
    end
  end

  def parse_draft_json(value)
    return value unless value.is_a?(String)

    JSON.parse(value)
  end

  # Autosave from the builder. A finished resume stays finished: it is
  # edited in place and must stay in not_drafts (the job CV picker).
  def save_draft(form_data)
    update!(
      draft_data: form_data,
      updated_at: Time.current
    )
  end

  def calculate_ats_score
    # Placeholder for ATS score calculation logic
    # This will be implemented in the AtsOptimizationService
  end

  def has_work_experience?
    work_experiences.any?
  end

  def has_skills?
    skills.any?
  end

  # Method to get the PDF URL for this resume
  def pdf_url
    "/resumes/#{id}/generate_pdf"
  end
end
