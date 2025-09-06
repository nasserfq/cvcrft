class AiTranslation < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true
  
  validates :arabic_text, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :english_text, length: { maximum: 5000 }
  validates :translation_quality, inclusion: { in: %w[low medium high] }, allow_nil: true
  validates :status, inclusion: { in: %w[pending processing completed failed] }
  
  # Set default status before creation
  before_create :set_default_status
  
  # Track AI model used and cost
  validates :ai_model, presence: true
  validates :tokens_used, numericality: { greater_than: 0 }, allow_nil: true
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  
  # Methods
  def processing?
    status == 'processing'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def pending?
    status == 'pending'
  end
  
  def has_quality_score?
    translation_quality.present?
  end
  
  def estimated_cost
    return 0 unless tokens_used
    
    # Placeholder for cost calculation based on AI model
    case ai_model
    when 'gpt-4' then tokens_used * 0.00003
    when 'gpt-3.5-turbo' then tokens_used * 0.000002
    else tokens_used * 0.00001
    end
  end
  
  private
  
  def set_default_status
    self.status ||= 'pending'
  end
end
