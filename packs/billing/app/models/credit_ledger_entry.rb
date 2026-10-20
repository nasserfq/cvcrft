class CreditLedgerEntry < ApplicationRecord
  REASONS = %w[
    signup_bonus purchase coupon coach_message refund admin_adjustment
    overage_summary_translation overage_jobs_translation
    overage_job_based_generation overage_document_ai
  ].freeze

  belongs_to :user

  validates :amount, numericality: { other_than: 0 }
  validates :reason, inclusion: { in: REASONS }
  validates :idempotency_key, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
