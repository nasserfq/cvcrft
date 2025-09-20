class Resume < ApplicationRecord
  belongs_to :user
  has_many :work_experiences, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :certifications, dependent: :destroy
  has_many :languages, dependent: :destroy
  has_many :ai_translations, dependent: :destroy
  has_many :cv_generations, dependent: :destroy

  # Accept nested attributes
  accepts_nested_attributes_for :work_experiences, allow_destroy: true
  accepts_nested_attributes_for :skills, allow_destroy: true
  accepts_nested_attributes_for :educations, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :certifications, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :languages, allow_destroy: true, reject_if: :all_blank

  # Validations for new fields
  validates :user_id, presence: true
  validates :complete_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
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

  # Methods
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
end
