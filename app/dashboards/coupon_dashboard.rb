require "administrate/base_dashboard"

class CouponDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    code: Field::String,
    description: Field::Text,
    unlimited: Field::Boolean,
    bonus_summary_translations: Field::Number,
    bonus_jobs_translations: Field::Number,
    bonus_cv_builder_generations: Field::Number,
    bonus_job_based_generations: Field::Number,
    expires_at: Field::DateTime,
    max_redemptions: Field::Number,
    redemptions_count: Field::Number,
    active: Field::Boolean,
    coupon_redemptions: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    code
    unlimited
    bonus_summary_translations
    bonus_jobs_translations
    redemptions_count
    active
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    code
    description
    unlimited
    bonus_summary_translations
    bonus_jobs_translations
    bonus_cv_builder_generations
    bonus_job_based_generations
    expires_at
    max_redemptions
    redemptions_count
    active
    coupon_redemptions
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    code
    description
    unlimited
    bonus_summary_translations
    bonus_jobs_translations
    bonus_cv_builder_generations
    bonus_job_based_generations
    expires_at
    max_redemptions
    active
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(coupon)
    coupon.code
  end
end
