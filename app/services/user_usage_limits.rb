class UserUsageLimits
  BASE_SUMMARY_TRANSLATIONS = 5
  BASE_JOBS_TRANSLATIONS = 5
  BASE_CV_BUILDER_GENERATIONS = 5
  BASE_JOB_BASED_GENERATIONS = 5

  def initialize(user)
    @user = user
  end

  def unlimited?
    @user.coupon_redemptions
      .joins(:coupon)
      .merge(Coupon.active.where(unlimited: true))
      .exists?
  end

  def max_summary_translations
    return nil if unlimited?

    BASE_SUMMARY_TRANSLATIONS + coupon_bonus(:bonus_summary_translations)
  end

  def max_jobs_translations
    return nil if unlimited?

    BASE_JOBS_TRANSLATIONS + coupon_bonus(:bonus_jobs_translations)
  end

  def max_cv_builder_generations
    return nil if unlimited?

    BASE_CV_BUILDER_GENERATIONS + coupon_bonus(:bonus_cv_builder_generations)
  end

  def max_job_based_generations
    return nil if unlimited?

    BASE_JOB_BASED_GENERATIONS + coupon_bonus(:bonus_job_based_generations)
  end

  def summary_translations_used
    @user.ai_translations
      .where("metadata->>'professional_summary' = ?", "true")
      .where(status: "completed")
      .count
  end

  def jobs_translations_used
    @user.ai_translations
      .where("metadata->>'job_descriptions' = ?", "true")
      .where(status: "completed")
      .count
  end

  def cv_builder_generations_used
    @user.cv_generations
      .where("metadata->>'source' = ?", "cv_builder")
      .where(status: "completed")
      .count
  end

  def job_based_generations_used
    @user.cv_generations
      .where("metadata->>'source' = ?", "job_description")
      .where(status: "completed")
      .count
  end

  def remaining_summary_translations
    return nil if unlimited?

    [ max_summary_translations - summary_translations_used, 0 ].max
  end

  def remaining_jobs_translations
    return nil if unlimited?

    [ max_jobs_translations - jobs_translations_used, 0 ].max
  end

  def remaining_cv_builder_generations
    return nil if unlimited?

    [ max_cv_builder_generations - cv_builder_generations_used, 0 ].max
  end

  def remaining_job_based_generations
    return nil if unlimited?

    [ max_job_based_generations - job_based_generations_used, 0 ].max
  end

  def can_translate_summary?
    unlimited? || remaining_summary_translations.positive?
  end

  def can_translate_jobs?
    unlimited? || remaining_jobs_translations.positive?
  end

  def can_generate_cv_builder?
    unlimited? || remaining_cv_builder_generations.positive?
  end

  def can_generate_job_based?
    unlimited? || remaining_job_based_generations.positive?
  end

  def as_json
    {
      unlimited: unlimited?,
      max_summary: max_summary_translations,
      used_summary: summary_translations_used,
      remaining_summary: remaining_summary_translations,
      max_jobs: max_jobs_translations,
      used_jobs: jobs_translations_used,
      remaining_jobs: remaining_jobs_translations,
      max_cv_builder: max_cv_builder_generations,
      used_cv_builder: cv_builder_generations_used,
      remaining_cv_builder: remaining_cv_builder_generations,
      max_job_based: max_job_based_generations,
      used_job_based: job_based_generations_used,
      remaining_job_based: remaining_job_based_generations,
      max: unlimited? ? nil : max_summary_translations + max_jobs_translations,
      used: @user.ai_translations.count,
      remaining: unlimited? ? nil : remaining_summary_translations + remaining_jobs_translations
    }
  end

  private

  def coupon_bonus(field)
    @user.coupon_redemptions
      .joins(:coupon)
      .merge(Coupon.active)
      .sum("coupons.#{field}")
  end
end
