class CvGeneration < ApplicationRecord
  belongs_to :user
  belongs_to :resume, optional: true

  # Validations
  validates :job_description, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :ai_model, presence: true
  validates :status, presence: true, inclusion: { in: %w[processing completed failed cancelled] }
  validates :tokens_used, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :completed, -> { where(status: 'completed') }
  scope :processing, -> { where(status: 'processing') }
  scope :failed, -> { where(status: 'failed') }

  # Methods
  def completed?
    status == 'completed'
  end

  def processing?
    status == 'processing'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end
end
