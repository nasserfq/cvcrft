# State machines

Every status in this app is a plain string column (no Rails `enum`, no gem). The allowed values are a
`STATUSES` constant with an `inclusion` validation, but `update_all` and `update_columns` skip it, so
code that uses them must only write values from the constant. Read this page before you change a
status, a job that writes one, a charge or a poller. Paths are under `packs/` unless they say otherwise.

## Rules for every machine

1. **Pass the record id to the job** and load the row by id (`cv_generation_id`, `translation_id`,
   `cv_analysis_id`, import id). Never find "the user's processing row" by content.
2. **Claim with a conditional update**: `where(id:, status: from).update_all(status: to) == 1`, or
   `with_lock` plus a status check. Only the caller that gets `1` goes on (and charges).
3. **Return early on a terminal row** at the start of `perform`. Retries and duplicate jobs must not
   call the AI again or flip `completed` back to `processing`.
4. **Write `failed` only when retries are exhausted** (`sidekiq_retries_exhausted`) or for an error
   a retry can't fix. Between attempts the row stays `processing`, so the page keeps polling.
5. **Charge after the cheap checks** (validation, PDF readable, row saved), through
   `Billing::UsageGate.allow!(user, kind, key:)`. Every charge has a key unique to the request; refund
   with the same key (`UsageGate.refund!`). Both are idempotent. Free uses are never given back.
6. **Every failure path that charged refunds**: enqueue error in the controller, final job failure,
   cancel, and the sweeper. A model's `fail_*!` method does the status write and the refund together.
7. **Pollers never show a client timeout as a failure.** Past the limit they show "taking longer" with
   "Check again"; limits are derived from `StaleWorkSweeperJob::STALE_AFTER`.
8. **Status JSON never carries backtraces, raw AI replies or PDF bytes** (see
   `CvGeneration::CLIENT_METADATA_KEYS`).
9. A new async model joins `StaleWorkSweeperJob::MODEL_NAMES` and implements `fail_stale!(older_than:)`.

## StaleWorkSweeperJob

`ai_tools/app/jobs/stale_work_sweeper_job.rb`, every 10 minutes (`config/schedule.yml`).
Calls `fail_stale!(older_than: 30.minutes.ago)` on CvGeneration, CvAnalysis, AiTranslation, CvImport,
LinkedinImport. Each skips rows that finished meanwhile and refunds credits where one was charged.
`CvGeneration::MAX_PROCESSING_TIME` = `STALE_AFTER + 10.minutes` (40 min) is the longest a row can stay
unfinished; pollers use it.

## CV generation

`ai_tools/app/models/cv_generation.rb` — `cv_generations.status` (no DB default), `is_draft`,
`draft_data`, `metadata` (`overage_key`, `error`, `pdf_generated`, `pdf_error`, `regenerating_at`).
States: `processing | completed | failed | cancelled | draft`. `draft?` is `is_draft || status == "draft"`.

| From → to | Method |
|---|---|
| new → processing | `CvGenerationService#generate_cv` (`ai_tools/app/services/cv_generation_service.rb`); charge in `CvGenerationsController#create` first |
| processing → completed | `CvGeneratorJob#mark_completed` (conditional on `processing`); content via `CvGenerator::ResultPersister#record!` (skips a cancelled row) |
| processing → failed | `CvGeneration#fail_processing!` (lock, refunds) from `sidekiq_retries_exhausted`, a non-retryable error, or the sweeper |
| processing → cancelled | `CvGeneration#cancel!` (conditional, refunds); also `destroy` cancels first |
| failed → processing | `CvGenerationService#retry_cv_generation` (conditional; block charges; back to failed if blocked) |
| draft → processing | `CvGenerationService#resume_draft` (conditional; back to draft if blocked or enqueue fails) |
| failed/cancelled/draft → draft | `CvGeneration#save_draft` (refuses processing and completed) |
| completed → completed | Regenerate: `CvGenerationsController#regenerate` (POST, rate-limited) claims with `claim_regeneration!` (10 min TTL), runs the job inline with `regenerate: true`; new summary and PDF are written together only on success, otherwise the old ones stay and the credit is refunded |

- The job only runs a `processing` row (or a `completed` one with `regenerate: true`). `failed` leaves
  via retry; `failed`/`cancelled` can be saved as a draft.
- Job: `CvGeneratorJob`, `retry: 3`; `ArgumentError`/`RecordNotFound` are killed at once. Retry and
  regenerate pass only `CvGeneratorJob::OPTION_KEYS` plus `cv_generation_id`.
- Refund key: `metadata["overage_key"]`, set only when the run cost credits.
- Rows with `ai_model == "cv_builder"` are legacy builder-export rows: excluded by `scope :ai_generated`
  from lists, the 150 cap and `CvGenerationPdfRegenerator` (which redraws PDFs from stored data, no AI).
- Pollers: `cv_generations/new.html.erb` (2 s → 5 s after 1 min → 10 s after 5 min, up to
  `MAX_PROCESSING_TIME`, then "taking longer" linking to the generation); `show.html.erb` every 4 s up
  to `MAX_PROCESSING_TIME`.

## CV analysis

`ai_tools/app/models/cv_analysis.rb` — `cv_analyses.status` (default `pending`), `progress` (0–100),
`error_message`. States: `pending → processing → completed | failed`.

- pending: `CvAnalysesController#create`, after the PDF text is read and `usage_limits.consume!(:document_ai)`
  passes (free allowance only; no credit fallback).
- processing: `CvAnalysis#mark_processing!` (resets progress to 3, clears the error) on each attempt.
- completed: `mark_completed!`. failed: `fail_unfinished!` (lock) from `sidekiq_retries_exhausted` or the sweeper.
- Job: `CvAnalysisJob.perform(cv_analysis_id)`, `retry: 3`, returns early on completed/failed.
- No refund (nothing charged in credits). `progress` is written with `update_column` from the job's threads.
- Pollers: `SeeraProgress.poll` (`app/views/shared/_ai_progress.html.erb`), default 180 s then "taking longer" + "Check again".

## AI translation

`ai_tools/app/models/ai_translation.rb` — `ai_translations.status` (default `pending`), `metadata`
(`job_id`, `translation_id`, `overage_kind`, `error_code`, `resume_updated_at`). States:
`pending → processing → completed | failed`.

- pending: `Api::TranslationsController#build_translation` + `enqueue_translation`
  (`ai_tools/app/controllers/api/translations_controller.rb`): validate the row (no charge if invalid),
  `UsageGate.allow!` with `job_id` as key, save, then `AiTranslationJob.perform_async(..., translation_id)`.
  Enqueue error → `translation_enqueue_failed` fails and refunds.
- processing: conditional `pending → processing` update at the start of `AiTranslationJob#perform`;
  retryable provider errors keep it processing (`mark_translation_retryable`).
- completed: `update_translation_success`, in one transaction with the resume/work-experience write.
  On a draft resume only the translated fields are validated (`save_translated_resume!`, then
  `save(validate: false)`); a finished resume is fully validated.
- failed: `handle_translation_error` (non-retryable, refunds), or `AiTranslation#fail_unfinished!` from
  `sidekiq_retries_exhausted` / the sweeper (refunds via `AiTranslationJob.refund_overage`).
- Terminal: completed, failed (job returns early on both).
- Job: `retry: 3`, backoff `5 * (count + 1)` s.
- Status: `GET /api/translation_status/:job_id`, answered from the row; 404 `not_found` if none.
- Pollers: `pollTranslation` in `app/frontend/components/MultiStepResumeForm.jsx` — 1 s × 30, then 5 s,
  up to 45 min; the result is applied to form state even after the "taking longer" notice.

## CV import and LinkedIn import

`imports/app/models/cv_import.rb`, `linkedin_import.rb` — `status` (default `pending`), `error_message`,
`parsed_data`, `resume_id`. States: `pending → processing → completed | failed`.

- pending: controller saves the row, then `UsageGate.allow!(:document_ai, key: import.charge_key)`
  (`"cv_import:<id>"` / `"linkedin_import:<id>"`); blocked → row destroyed and a limit error.
- processing: `mark_processing!` per attempt. completed: `mark_completed!` under `with_lock`, unless terminal.
- failed: `CvImport.fail_active!` / `LinkedinImport.fail_active!` (conditional on pending/processing,
  refunds) from `sidekiq_retries_exhausted`, controller errors and the sweeper.
- Terminal: `TERMINAL_STATUSES` (`terminal?`); the job returns early on them.
- Jobs: `retry: 3`, backoff `10 * (count + 1)` s.
- LinkedIn: `update` and `save_to_cv` only on completed; `save_to_cv` is idempotent (row lock, returns
  the resume already linked).
- Pollers: `CvImportModal.jsx` 2 s, after 3 min "taking longer" + "Check again" and 10 s polls (never a
  false failure); LinkedIn `status.html.erb` via `SeeraProgress.poll` (180 s, then "Check again").

## Resume draft

`resume_builder/app/models/resume.rb` — `resumes.is_draft`, `draft_data` (incl. `current_step`, `saved_at`).

| Transition | Method |
|---|---|
| new draft | `ResumesController#new` / `find_or_create_draft_resume` (`save(validate: false)`; reuses an empty starter draft) |
| autosave | `POST /resumes/:id/save_draft` → `Resume#save_draft` under `with_lock`; `base_updated_at` older than the row → 409 with the current `updated_at` |
| draft → finished | `PATCH /resumes/:id` (JSON) → `finish_resume`: replaces sections, sets `is_draft: false`, full validation; idempotent on retry |
| open a draft | `resume_draft` → redirect to edit; it stays a draft (`can_be_resumed?` is `draft?`) |
| coach → finished | `ResumeBuilder::PublicApi.create_from_draft` (one transaction) |

- `save_draft` never turns a finished resume back into a draft. Saving renders no PDF; PDFs are drawn
  on request by `Api::TranslationsController#export_pdf` → `CvBuilderPdfJob#perform` (inline).
- Background writers (translation job) must not fail on a draft's missing fields; see AI translation.

## Coach turn and send_to_seera

No status column. `Coach::Chat#turn_running?` (`coach/app/models/coach/chat.rb`): the newest message is
the user's, not ended (`Message#turn_ended?` = `updated_at > created_at`), and younger than
`Chat::TURN_TIMEOUT` (2 min, so a crashed job can't block the chat).

- start: `Coach::ChatsController#message` under `@chat.with_lock`: busy → 409; save message;
  `Coach.charge!` (key `coach_message:<message id>`); then `Coach::TurnJob.perform_later(chat_id, message_id)`.
- end: `TurnJob` saves the assistant message (turn over). On error it never re-raises (a retry would
  send a second reply); if no reply was saved it calls `end_turn!` on that message and `Coach.refund!`.
- Proposals: `settle_proposal` changes `proposals`/`draft` under the chat lock.
- `send_to_seera`: under the chat lock, returns `coach_chats.resume_id` if that resume still belongs to
  the user, otherwise creates one with `create_from_draft` and stores its id.
- Client: `CoachChat.jsx` watchdog, 60 s without a chunk → timeout notice with reload.

## Credit purchase (Moyasar)

`billing/app/models/credit_purchase.rb` — `status` (default `pending`), `paid_at`, `moyasar_invoice_id`
(unique). States: `pending → paid | failed`. `billing/app/services/billing/checkout.rb`:

- pending: `Checkout#start!`; invoice creation or save error → `failed`.
- paid: `Checkout#settle!` (redirect and callback both call it) reads the invoice from Moyasar, checks
  id/amount/currency, then under `with_lock` grants credits (key `purchase:<id>`) and sets paid.
- failed: `fail!` when Moyasar says expired/failed/canceled; only from pending.
- Terminal: paid, failed. No sweeper: a pending row changes only when settle! sees a final invoice.

## Credit wallet and ledger

`users.credit_balance` + `credit_ledger_entries` (`idempotency_key` unique). `billing/app/services/billing/credits.rb`:
every change is `insert!` under `user.with_lock`; a repeated key is a no-op. `spend!` refuses overspend.
`ensure_signup_bonus!` (key `signup_bonus:<user id>`, skipped when `SIGNUP_BONUS_CREDITS=0`).
Refunds are `grant!` with key `refund:<charge key>`. Reasons: `CreditLedgerEntry::REASONS`.

## Free-tier counters

`users.summary_translations_count`, `jobs_translations_count`, `job_based_generations_count`,
`document_ai_count`. Only increase, only via `UserUsageLimits#consume!` (`accounts/app/services/user_usage_limits.rb`)
under the user row lock. `UsageGate.allow!` uses them before credits. Never decremented on failure.

## OTP

`accounts/app/models/otp_verification.rb` — `verified`, `expires_at` (10 min), `failed_attempts` (max 5).
Derived states: pending (`scope :valid`), verified, expired, burned.

- created: `OtpVerification.generate_for` (one transaction: delete old codes for the email, create).
- verify: `verify!` reserves an attempt atomically, compares, then `verified: false → true` conditionally.
- `SendOtpEmailJob` takes the id and sends only if the code is still `valid`.
- `DataRetentionJob` deletes codes after 1 day.

## Coupons (unchanged by owner decision)

`config/coupons.yml` (`ConfigCoupon`, `CouponRegistry`) plus the Redis sets in `CouponRedemptionStore`
(memory backend in tests). `CouponService.redeem`: `redeemable?` → `allowed_for?` → `redeemed?` →
`redeem!` → `Credits.grant!` (key `coupon:<code>:<user id>`). The `coupons` / `coupon_redemptions` tables
are not used. Known gaps (no global cap, `active: false` does not revoke perks, Redis is the only record)
are left as they are on purpose; don't "fix" them without the owner.

## Privacy consent

`users.privacy_accepted_at`, `privacy_policy_version`, written only by `User#record_privacy_consent!`.
OTP: `send_otp` needs the consent flag; `verify_otp` records it when the flag is sent. Social sign-in
(`accounts/app/services/social_sign_in.rb`) needs consent or an earlier `privacy_accepted_at`. The
version is stored but not yet compared with `PrivacyPolicy::VERSION` (no re-consent on a policy bump).
