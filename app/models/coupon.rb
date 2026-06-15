class Coupon < ApplicationRecord
  has_many :coupon_redemptions, dependent: :destroy
  has_many :users, through: :coupon_redemptions

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :bonus_summary_translations,
            :bonus_jobs_translations,
            :bonus_cv_builder_generations,
            :bonus_job_based_generations,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :has_at_least_one_benefit

  before_validation :normalize_code

  scope :active, -> { where(active: true).where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def self.find_redeemable_by_code!(code)
    active.find_by!(code: code.to_s.strip.upcase)
  end

  def redeemable?
    active? && !expired? && !max_redemptions_reached?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def max_redemptions_reached?
    max_redemptions.present? && redemptions_count >= max_redemptions
  end

  def redeem_for!(user)
    raise ActiveRecord::RecordInvalid, self unless redeemable?

    transaction do
      lock!
      raise ActiveRecord::RecordInvalid, self unless redeemable?
      if coupon_redemptions.exists?(user: user)
        errors.add(:base, "already redeemed by this user")
        raise ActiveRecord::RecordInvalid, self
      end

      coupon_redemptions.create!(user: user, redeemed_at: Time.current)
      increment!(:redemptions_count)
    end
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase if code.present?
  end

  def has_at_least_one_benefit
    return if unlimited?

    bonuses = [
      bonus_summary_translations,
      bonus_jobs_translations,
      bonus_cv_builder_generations,
      bonus_job_based_generations
    ]

    return if bonuses.any?(&:positive?)

    errors.add(:base, "Coupon must grant unlimited access or at least one bonus")
  end
end
