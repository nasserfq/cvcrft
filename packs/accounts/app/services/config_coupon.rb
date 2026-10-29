class ConfigCoupon
  attr_reader :code, :description, :bonus_summary_translations, :bonus_jobs_translations,
              :bonus_cv_builder_generations, :bonus_job_based_generations, :bonus_credits, :expires_at,
              :emails

  def initialize(code, attrs = {})
    attrs = attrs.to_h.stringify_keys
    @code = code.to_s.strip.upcase
    @description = attrs["description"]
    @active = attrs.fetch("active", true)
    @unlimited = attrs.fetch("unlimited", false)
    # Also lifts the coach's daily cap and per-message charges.
    @unlimited_coach = attrs.fetch("unlimited_coach", false)
    # CouponRegistry.digest of each account email that may redeem it; empty means anyone.
    @emails = Array(attrs["emails"]).map { |email| email.to_s.strip.upcase }
    @bonus_summary_translations = attrs.fetch("bonus_summary_translations", 0).to_i
    @bonus_jobs_translations = attrs.fetch("bonus_jobs_translations", 0).to_i
    @bonus_cv_builder_generations = attrs.fetch("bonus_cv_builder_generations", 0).to_i
    @bonus_job_based_generations = attrs.fetch("bonus_job_based_generations", 0).to_i
    # Billing credits for the AI coach, granted once when the coupon is redeemed.
    @bonus_credits = attrs.fetch("bonus_credits", 0).to_i
    @expires_at = parse_expires_at(attrs["expires_at"])
  end

  def active?
    @active
  end

  def unlimited?
    @unlimited
  end

  def unlimited_coach?
    @unlimited_coach
  end

  def allowed_for?(user)
    emails.empty? || emails.include?(CouponRegistry.digest(user.email))
  end

  def redeemable?
    active? && !expired?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def as_json
    {
      code: code,
      unlimited: unlimited?,
      bonus_summary_translations: bonus_summary_translations,
      bonus_jobs_translations: bonus_jobs_translations,
      bonus_cv_builder_generations: bonus_cv_builder_generations,
      bonus_job_based_generations: bonus_job_based_generations,
      bonus_credits: bonus_credits
    }
  end

  private

  def parse_expires_at(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
