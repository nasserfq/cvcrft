class UserUsageLimits
  BASE_SUMMARY_TRANSLATIONS = 5
  BASE_JOBS_TRANSLATIONS = 5
  BASE_JOB_BASED_GENERATIONS = 20
  # CV analysis, CV import and LinkedIn import share one allowance.
  BASE_DOCUMENT_AI = 20

  # kind => counter column on users. Counters only go up, so deleting content
  # never gives quota back, and they are bumped before the AI work is queued.
  COUNTERS = {
    summary_translation: :summary_translations_count,
    jobs_translation: :jobs_translations_count,
    job_based_generation: :job_based_generations_count,
    document_ai: :document_ai_count
  }.freeze

  def initialize(user)
    @user = user
  end

  def unlimited?
    redeemed_coupons.any?(&:unlimited?)
  end

  def max_summary_translations
    return nil if unlimited?

    BASE_SUMMARY_TRANSLATIONS + coupon_bonus(:bonus_summary_translations)
  end

  def max_jobs_translations
    return nil if unlimited?

    BASE_JOBS_TRANSLATIONS + coupon_bonus(:bonus_jobs_translations)
  end

  def max_job_based_generations
    return nil if unlimited?

    BASE_JOB_BASED_GENERATIONS + coupon_bonus(:bonus_job_based_generations)
  end

  def max_document_ai
    return nil if unlimited?

    BASE_DOCUMENT_AI
  end

  # Usage is the counter, or the legacy count of completed rows for accounts
  # that used features before the counters existed, whichever is higher.
  def summary_translations_used
    [ @user.summary_translations_count,
      @user.ai_translations
        .where("metadata->>'professional_summary' = ?", "true")
        .where(status: "completed")
        .count ].max
  end

  def jobs_translations_used
    [ @user.jobs_translations_count,
      @user.ai_translations
        .where("metadata->>'job_descriptions' = ?", "true")
        .where(status: "completed")
        .count ].max
  end

  def document_ai_used
    @user.document_ai_count
  end

  def job_based_generations_used
    [ @user.job_based_generations_count,
      @user.cv_generations
        .where("metadata->>'source' = ?", "job_description")
        .where(status: "completed")
        .count ].max
  end

  def remaining_summary_translations
    return nil if unlimited?

    [ max_summary_translations - summary_translations_used, 0 ].max
  end

  def remaining_jobs_translations
    return nil if unlimited?

    [ max_jobs_translations - jobs_translations_used, 0 ].max
  end

  def remaining_job_based_generations
    return nil if unlimited?

    [ max_job_based_generations - job_based_generations_used, 0 ].max
  end

  def remaining_document_ai
    return nil if unlimited?

    [ max_document_ai - document_ai_used, 0 ].max
  end

  def can_use_document_ai?
    unlimited? || remaining_document_ai.positive?
  end

  # Atomically checks and records one use of an AI feature. Returns false,
  # recording nothing, when the user has no allowance left. The row lock
  # stops parallel requests from all passing the check.
  def consume!(kind)
    column = COUNTERS.fetch(kind)
    allowed = false

    @user.with_lock do
      allowed = unlimited? || remaining_for(kind).positive?
      @user.increment!(column) if allowed
    end

    allowed
  end

  # Whether the free allowance (base plus coupons) still covers one use of
  # kind. Past it, Billing::UsageGate may charge a credit instead.
  def free_available?(kind)
    case kind
    when :summary_translation then can_translate_summary?
    when :jobs_translation then can_translate_jobs?
    when :job_based_generation then can_generate_job_based?
    when :document_ai then can_use_document_ai?
    else raise KeyError, "unknown usage kind: #{kind.inspect}"
    end
  end

  def can_translate_summary?
    unlimited? || remaining_summary_translations.positive?
  end

  def can_translate_jobs?
    unlimited? || remaining_jobs_translations.positive?
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
      max_job_based: max_job_based_generations,
      used_job_based: job_based_generations_used,
      remaining_job_based: remaining_job_based_generations,
      max: unlimited? ? nil : max_summary_translations + max_jobs_translations,
      used: @user.ai_translations.count,
      remaining: unlimited? ? nil : remaining_summary_translations + remaining_jobs_translations
    }
  end

  private

  def remaining_for(kind)
    case kind
    when :summary_translation then remaining_summary_translations
    when :jobs_translation then remaining_jobs_translations
    when :job_based_generation then remaining_job_based_generations
    when :document_ai then remaining_document_ai
    end
  end

  def redeemed_coupons
    CouponRedemptionStore.redeemed_codes_for(@user.id).filter_map do |code|
      CouponRegistry.all.find { |coupon| coupon.code == code }
    end
  end

  def coupon_bonus(field)
    redeemed_coupons.sum { |coupon| coupon.public_send(field) }
  end
end
