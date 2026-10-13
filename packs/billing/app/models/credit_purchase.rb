class CreditPurchase < ApplicationRecord
  STATUSES = %w[pending paid failed].freeze

  belongs_to :user

  validates :pack, :credits, :amount_halalas, :currency, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def paid?
    status == "paid"
  end

  def amount_sar
    amount_halalas / 100.0
  end
end
