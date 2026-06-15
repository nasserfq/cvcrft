coupon = Coupon.find_or_initialize_by(code: "NAIF2026")
coupon.assign_attributes(
  description: "Unlock unlimited translations and CV generations",
  unlimited: true,
  bonus_summary_translations: 0,
  bonus_jobs_translations: 0,
  bonus_cv_builder_generations: 0,
  bonus_job_based_generations: 0,
  active: true
)
coupon.save!

Coupon.where(code: "CVCRFT20").update_all(active: false)
