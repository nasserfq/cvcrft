class Resume < ApplicationRecord
  belongs_to :user
  has_many :work_experiences, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :languages, dependent: :destroy
  has_many :ai_translations, dependent: :destroy
  has_many :cv_generations, dependent: :destroy

  # Generate PDF after saving a resume - queue it for background processing
  after_create :queue_pdf_generation
  after_update :queue_pdf_generation

  # Add a flag to allow skipping validations for PDF generation only
  attr_accessor :skip_validations_for_pdf

  # Queue PDF generation in the background
  def queue_pdf_generation
    # Only queue if the resume has been persisted
    if persisted? && !is_draft
      Rails.logger.info "Queueing PDF generation for Resume ##{id}"
      CvBuilderPdfJob.schedule_pdf_generation(
        user_id,
        id, # resume_id
        false, # view in browser
        nil # no resume_params needed as we're using an existing resume
      )
    end
  rescue => e
    Rails.logger.error "Error queueing PDF generation: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

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

  # Legacy validations (keeping for backward compatibility)
  validates :title, length: { minimum: 3, maximum: 100 }, allow_blank: true
  validates :target_position, length: { minimum: 3, maximum: 100 }, allow_blank: true
  validates :summary, length: { minimum: 50, maximum: 1000 }, allow_blank: true

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

  def can_be_resumed?
    draft? || (created_at > 1.hour.ago && complete_name.blank?)
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

  def save_draft(form_data)
    update!(
      is_draft: true,
      draft_data: form_data,
      updated_at: Time.current
    )
  end

  def complete_draft
    update!(
      is_draft: false
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
