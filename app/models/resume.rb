class Resume < ApplicationRecord
  belongs_to :user
  has_many :work_experiences, dependent: :destroy
  has_many :skills, dependent: :destroy
  has_many :ai_translations, dependent: :destroy
  
  validates :title, presence: true, length: { minimum: 3, maximum: 100 }
  validates :target_position, presence: true, length: { minimum: 3, maximum: 100 }
  validates :summary, presence: true, length: { minimum: 50, maximum: 1000 }
  
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
