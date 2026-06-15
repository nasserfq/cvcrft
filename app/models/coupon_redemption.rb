class CouponRedemption < ApplicationRecord
  belongs_to :user
  belongs_to :coupon

  validates :user_id, uniqueness: { scope: :coupon_id }
  validates :redeemed_at, presence: true
end
