# State machine fixes (2026-11-07)

Source: audit report `/mnt/project-files/state-machines/report.md`. Nasser asked to fix the code bugs it lists.
Out of scope (product decisions left to Nasser): global coupon cap, coupon DB-vs-Redis, revoking redeemed coupons on deactivate, re-consent on policy bump, ledger retention on account deletion, giving back free-allowance uses on failure.

Rules for every unit: no visible UI/copy changes beyond what a fix needs; no new gems; keep string status columns (no migration needed unless stated); match existing style; add tests in `test/`.

Shared contract (used by unit 1's sweeper job, implemented by units 1-3 on their own models):
`Model.fail_stale!(older_than:)` — finds rows in `pending`/`processing` whose `updated_at < older_than`, moves each to `failed` with an `error_message`/metadata error of "timed out", refunds any credit charged for it (same refund path the job's `sidekiq_retries_exhausted` uses), and returns the number of rows changed. Use a conditional update (`where(status: [...]).update_all` per id, or `with_lock` + re-check) so it never overwrites a row that finished meanwhile.

General job rule (units 1-3): write `failed` only when Sidekiq retries are exhausted (or for a non-retryable error that is re-raised as no-retry). Between attempts the row stays `processing`. At the start of `perform`, return early if the row is already in a terminal state (`completed`, `cancelled`).

## Unit 1 — CV generation (packs/ai_tools: cv_generator_job.rb, cv_generation_service.rb, cv_generator/*, models/cv_generation.rb, controllers/cv_generations_controller.rb, views/cv_generations/*, packs/admin/app/dashboards/cv_generation_dashboard.rb, new packs/ai_tools/app/jobs/stale_work_sweeper_job.rb, config/schedule.yml)
1. Pass the CvGeneration id to CvGeneratorJob and load the row by id (scoped to the user). Keep the old `(job_description, processing)` finder only as a fallback for jobs already enqueued without an id. Never create a second row from the job when an id was given.
2. Regenerate PDF (download_pdf/view_pdf with regenerate) must update the same record the user is viewing, so the reload serves the new PDF.
3. Cancel: the job re-checks the status before persisting and stops if `cancelled`; ResultPersister must not overwrite `cancelled`. Cancelling refunds the charge (UsageGate.refund! with the stored overage key; idempotent).
4. `create`: if enqueueing raises after `create!`, mark the row failed and refund.
5. `save_draft` must not turn a `processing` or `completed` row into a draft (no-op or error the controller already handles).
6. Polling in new.html.erb treats `cancelled` and `draft` as terminal; show.html.erb poll gets an attempt cap like new.html.erb.
7. Admin dashboard: status field becomes a select of the allowed values.
8. `preview_resume` calls a non-existent `perform_resume_preview`: make it work with an existing method if one fits, otherwise leave and report.
9. Implement `CvGeneration.fail_stale!`. Create `StaleWorkSweeperJob` (Sidekiq job like DataRetentionJob) that calls `fail_stale!(older_than: 30.minutes.ago)` on CvGeneration, CvAnalysis, AiTranslation, CvImport, LinkedinImport (guard each with `respond_to?` so it runs before other units land), and add it to config/schedule.yml every 10 minutes.
Tests: test/jobs/cv_generator_job_test.rb, test/models/cv_generation_test.rb, cv_generations controller tests, new test/jobs/stale_work_sweeper_job_test.rb.

## Unit 2 — CV analysis + AI translation (packs/ai_tools: cv_analysis_job.rb, models/cv_analysis.rb, controllers/cv_analyses_controller.rb, ai_translation_job.rb, models/ai_translation.rb, controllers/api/translations_controller.rb, controllers/ai_translations_controller.rb + its route; packs/admin/app/dashboards/ai_translation_dashboard.rb; app/frontend MultiStepResumeForm.jsx (only the jobs-poll success check); packs/resume_builder: controllers/work_experiences_controller.rb, models/work_experience.rb)
1. CvAnalysis: call `consume!(:document_ai)` only after the PDF text is extracted and non-blank; follow the general job rule; clear `error_message` and reset progress when an attempt restarts. Implement `CvAnalysis.fail_stale!`.
2. AiTranslation: update the resume / work experiences / skills first (in a transaction), then mark `completed`. Terminal guard on retry (don't call the AI again for a completed row). A result with no usable jobs (empty array after parsing) is `failed` + refund, not `completed`. Implement `AiTranslation.fail_stale!`.
3. MultiStepResumeForm.jsx: the jobs poll must not treat `completed` with an empty `jobs` list as success.
4. AiTranslationsController#create enqueues with the wrong arguments: if nothing in the UI uses it, remove the action and route; otherwise fix the call. Report which.
5. WorkExperiencesController#create calls `AiTranslationJob.perform_async(id)` with the wrong arity: remove that enqueue (translation is user-driven in the form).
6. WorkExperience `belongs_to :ai_translation` has no column: remove it (check no caller uses it). Remove unused `needs_translation?` if unused.
7. The builder-PDF CvGeneration seed in api/translations_controller.rb (around lines 237 and 306) may fail `validates :job_description, presence`. Verify with a test; fix by giving it a job_description value that fits (do not loosen the model validation, which unit 1 owns).
8. Admin ai_translation_dashboard status becomes a select.
Tests: test/jobs/cv_analysis_job_test.rb, test/jobs/ai_translation_job_test.rb, related controller tests, model tests.

## Unit 3 — Imports (packs/imports: cv_import_job.rb, linkedin_import_job.rb, models, controllers, views/linkedin_imports/status.html.erb; app/frontend CvImportModal.jsx)
1. General job rule for both jobs (terminal guard, failed only on exhaustion).
2. LinkedIn: if anything after the charge fails (not only LinkedinPdfParseError), refund.
3. `PATCH update` must not run while the import is `processing` (reject).
4. `save_to_cv` idempotent: if the import already has a resume, return/redirect to it instead of creating another.
5. Polling: CvImportModal.jsx and linkedin_imports/status.html.erb stop after a cap (about 3 minutes) and show the existing failure state.
6. Implement `CvImport.fail_stale!` and `LinkedinImport.fail_stale!`.
Tests: test/jobs/cv_import_job_test.rb, test/jobs/linkedin_import_job_test.rb, controller tests.

## Unit 4 — Accounts (packs/accounts: controllers/auth_controller.rb, services/coupon_service.rb, services/user_usage_limits.rb, models/otp_verification.rb)
1. OTP sign-up name: when the email local part is shorter than 2 chars, use a fallback that passes validation (mirror SocialSignIn's fallback).
2. Don't burn the OTP code when the user can't be created: build/validate the user before consuming the code, while keeping the code check itself first for security (wrong code must still count an attempt). Simplest correct order: verify code → find_or_initialize user with valid name → save!; with the name fallback the save can't fail on name. Make sure a RecordNotUnique race (concurrent Google sign-in) retries the find instead of showing failure.
3. CouponService.redeem: grant the bonus credits before marking redeemed in Redis (grant is idempotent by key), so a failed grant doesn't leave a redeemed-without-credits user.
4. UserUsageLimits#consume!: load redeemed coupon data before taking the row lock so no Redis calls happen inside the lock.
5. `OtpVerification.generate_for`: wrap destroy_all + create in a transaction.
Tests: test/models/otp_verification_test.rb, auth controller tests, coupon service tests, user usage limits tests.

## Unit 5 — Billing (packs/billing: services/billing/checkout.rb, services/billing/credits.rb, controllers/credits_controller.rb, models/credit_purchase.rb)
1. `ensure_signup_bonus!` does nothing when SIGNUP_BONUS is not positive (no raise).
2. `start!`: if any error happens after the Moyasar invoice is created but before the purchase is saved with its id, mark the purchase failed and re-raise (the user never saw the invoice URL).
3. `settle!`: Moyasar invoice statuses that are final and unpaid (expired, failed, canceled/cancelled — check MoyasarClient/tests for names) move the purchase to `failed`. Never touch a `paid` row.
4. Callback lookup: try both `params[:id]` and `params.dig(:data, :invoice_id)` (and `data.id`) before giving up.
5. Add `CreditPurchase.fail_stale!`-style expiry is NOT needed; settle! on callback/return is enough.
Tests: billing service and controller tests.
