# PDPL compliance (Saudi Personal Data Protection Law)

Date: 2026-10-19. Scope is fixed (8 items from the brief); do not expand it.

## 1. Goal

- Login shows a required "I agree to the Privacy Policy and Terms" checkbox (ar/en, real links). Without it no code is sent. The user row stores when and which policy version they accepted.
- `/privacy` is a full PDPL policy in Arabic or English (follows the current locale), same visual shell as today, with a fixed "last updated" date. `/terms` stops naming OpenAI and links to the policy.
- Profile page has "Download my data" (JSON file `seera-data-<date>.json`) next to "Delete my account". Deleting works even with imports/coupons, runs in one transaction, and sends nothing identifying to PostHog.
- A daily Sidekiq job enforces retention. Logs stop carrying emails and CV content. Sentry/PostHog stop sending user PII. SES verifies TLS. `docs/pdpl.md` records processing and the breach procedure.

## 2. Approach

**Consent** is a plain HTML form post: `login.html.erb:93` posts to `/auth/send_otp` with no JS, and `AuthController#send_otp` answers with redirect + flash only. There is no JSON shape to match, so the rejection is the same redirect-with-alert pattern as the bad-email branch (`auth_controller.rb:31-34`), with the message from `t()`. The checkbox (`name="privacy_consent" value="1" required`) is on the email form only. The OTP form is a second request, so the email form's consent is carried as a hidden field `privacy_consent=1`, and `verify_otp` writes `privacy_accepted_at`/`privacy_policy_version` for new and returning users (refreshes the version each login). A missing flag on verify skips the write but does not block login (old links already in mailboxes). `PrivacyPolicy::VERSION = "2026-10-19"` lives in `app/models/privacy_policy.rb` (root package: both the pages and `accounts` can reference it, no Packwerk edge). Note that the rate-limit and rescue messages in the controller stay hard-coded Arabic. Only the new strings are bilingual (out of scope).

**Privacy page.** The legal text is long prose, so we use two partials `app/views/pages/privacy/_body_ar.html.erb` and `_body_en.html.erb` instead of hundreds of i18n keys. `privacy.html.erb` keeps its `<head>` and hero/card markup, sets `lang`/`dir` from `I18n.locale`, and renders `"pages/privacy/body_#{I18n.locale == :en ? 'en' : 'ar'}"`. Each partial reuses the existing section card classes exactly. The partial approach keeps translators editing prose, not YAML. Controller: `privacy@cvcrft.com` (domain from `config/deploy.yml:14`).

**Export** is a PORO `UserDataExport` in `packs/accounts/app/services`. It reaches other packs only through `User` associations (`user.resumes`, `user.cv_imports` ...), so it never names `Resume` (`resume_builder` has `enforce_privacy: true`, public API only). `Coach::Chat.where(user_id:)` is allowed: `accounts` has `enforce_dependencies: false` and coach has `enforce_privacy: false`. Pdf blobs are dropped with `metadata.except("pdf_data")`, and users get `slice` of an allow-list of columns (never `encrypted_password`/`reset_password_token`).

**Scheduling: the `sidekiq-cron` gem** (2.4.0 resolves from rubygems here; it supports Sidekiq 8). A self-rescheduling job is the "no dependency" alternative. But if one run dies after its retries, the chain silently stops until a restart, and duplicate chains need a hand-written Redis lock. sidekiq-cron stores the schedule in Redis, survives deploys, dedupes across processes and shows in Sidekiq Web. The cost is one gem. `config/recurring.yml` is Solid Queue's and is not used (adapter is `:sidekiq`, `config/application.rb:49`).

## 3. Work units

Shared-file ownership: every unit adds its locale strings in **its own new locale files** (`config/locales/pdpl_<unit>.{ar,en}.yml`, picked up by the default `config/locales/*.yml` load path, like `emails.ar.yml`). Nobody edits `config/locales/ar.yml`/`en.yml`. `config/routes.rb` belongs to U3 only. `db/migrate` and `db/schema.rb` belong to U1 only. `Gemfile`/`Gemfile.lock` belong to U4 only.

**U1. Consent at login** (pack `accounts` + root model). No dependencies; land first or in parallel (others only need the constant name).
- `app/models/privacy_policy.rb` (new): `module PrivacyPolicy; VERSION = "2026-10-19"; def self.last_updated = Date.iso8601(VERSION); end`
- `db/migrate/20261019000100_add_privacy_consent_to_users.rb` (new), `db/schema.rb`
- `packs/accounts/app/controllers/auth_controller.rb`: consent check in `send_otp` after the email check, and the consent write in `verify_otp` after `find_or_create_by` (`update_columns` is fine, no validations needed).
- `packs/accounts/app/views/auth/login.html.erb`: checkbox inside the email form (before submit, `:93-113`), hidden `privacy_consent` in the OTP form, footer `:166-171` text changed to links with `terms_path`, replacing `href="#"` at `:168`.
- `config/locales/pdpl_consent.ar.yml`, `pdpl_consent.en.yml` (namespace `pdpl_consent:` with `checkbox_html`, `required`). Do not reuse `consent:` (that is the analytics cookie banner).
- `test/controllers/auth_controller_test.rb`

**U2. Privacy and terms pages** (root `app/`). Uses `PrivacyPolicy` (soft dependency on U1; stub the constant if U1 has not landed).
- `app/views/pages/privacy.html.erb`: lang/dir from locale, date from `PrivacyPolicy.last_updated`, render partial. Keep the head/layout/script blocks.
- `app/views/pages/privacy/_body_ar.html.erb`, `_body_en.html.erb` (new). Sections in this order: controller and contact; data collected; purposes; legal basis (consent/contract/legitimate interest); processors and locations (netcup Germany hosting; AWS Bedrock USA AI; AWS SES USA email; Sentry error monitoring; PostHog USA analytics only with cookie consent; Moyasar payments KSA; TypeSafe Jev AI quality check of coach answers); cross-border transfer notice; retention (copy the table from U4); rights (access, copy/export, correction, deletion, withdraw consent, complaint to SDAIA); how to exercise them (profile export/delete + privacy@cvcrft.com); security and breach (SDAIA within 72 h, affected users without undue delay); children (no under 18); changes (version/date, re-consent on material change). Remove "OpenAI" and "never shared".
- `app/views/pages/terms.html.erb`: replace `Date.today` (`:56`) with `PrivacyPolicy.last_updated`, fix any wrong processor facts, add a link to `privacy_path`. Light touch, Arabic as is.
- `config/locales/pdpl_pages.{ar,en}.yml` (namespace `pdpl_pages:`) for the title, "last updated" and the locale-neutral labels.
- `app/views/shared/_site_footer.html.erb`: no change (it already links both, `:9-10`).
- `test/controllers/pages_controller_test.rb` (new)

**U3. Profile: export and deletion** (pack `accounts` + one line in `resume_builder`). Independent.
- `config/routes.rb:39-41`: `resource :profile, only: [:show, :destroy] do get :export, on: :member; post :redeem_coupon ... end` gives `export_profile_path` → `GET /profile/export`.
- `packs/accounts/app/services/user_data_export.rb` (new): `#as_json` / `#filename`. Keys: `user`, `resumes` (each with work_experiences, educations, skills, certifications, languages), `cv_analyses`, `cv_imports`, `linkedin_imports`, `cv_generations` (metadata without `pdf_data`), `ai_translations`, `coach_chats` (with messages), `credit_ledger_entries`, `credit_purchases`, `exported_at`, `privacy_policy_version`.
- `packs/accounts/app/controllers/profiles_controller.rb`: `export` uses `send_data json, filename:, type: "application/json", disposition: "attachment"`. `destroy` captures nothing identifying (no `email`/`user_id` props; keep the count-only `account_deleted` event *before* the delete, or drop it), then `ActiveRecord::Base.transaction { OtpVerification.where(email: user.email).delete_all; user.destroy! }`, then `CouponRedemptionStore.forget_user!(user.id)` after commit, then `sign_out`, then redirect. Drop the manual `resumes/cv_generations/ai_translations.destroy_all` (User's `dependent:` covers them). Notice comes from `t()`.
- `packs/accounts/app/models/user.rb`: `has_many :coupon_redemptions, dependent: :delete_all`.
- `packs/accounts/app/models/coupon_redemption.rb` (new, `belongs_to :user`). The table exists (`db/schema.rb:65`) with no model.
- `packs/accounts/app/services/coupon_redemption_store.rb`: `forget_user!(user_id)` on both backends (`srem` over `CouponRegistry.all` keys; memory backend deletes from each set).
- `packs/resume_builder/app/models/resume.rb:10`: add `has_many :cv_imports, dependent: :nullify` and `has_many :linkedin_imports, dependent: :nullify`. Keep `has_one :linkedin_import` for its readers, but drop its `dependent:` so only the has_many nullifies.
- `packs/accounts/app/views/profiles/show.html.erb` (`:414-426`): "Download my data" `link_to export_profile_path` above the delete button, same card.
- `config/locales/pdpl_profile.{ar,en}.yml` (namespace `pdpl_profile:` with `export_button`, `export_hint`, `deleted_notice`)
- `test/controllers/profiles_controller_test.rb`, `test/services/user_data_export_test.rb` (new), `test/models/user_test.rb`

**U4. Retention job and schedule** (pack `accounts`). Independent.
- `Gemfile`, `Gemfile.lock`: `bundle add sidekiq-cron --version "~> 2.4"`.
- `config/schedule.yml` (new): `data_retention: { cron: "15 3 * * *", class: "DataRetentionJob", queue: default }` (ActiveJob class; sidekiq-cron wraps it).
- `config/initializers/sidekiq.rb`: inside `configure_server`, `Sidekiq::Cron::Job.load_from_hash!(YAML.load_file(Rails.root.join("config/schedule.yml")))` if the file exists (`load_from_hash!` also removes stale jobs).
- `packs/accounts/app/jobs/data_retention_job.rb` (new, `queue_as :default`). Cutoff is `30.days.ago`. Each step is a batched `delete_all`/`update_all` via `in_batches`, and it logs counts only:
  - `OtpVerification.where(created_at: ...1.day.ago).delete_all`
  - `CvAnalysis`, `CvImport`, `LinkedinImport`: `.failed.where(created_at: ...cutoff).delete_all` (check for dependents first; `cv_imports.resume_id` points *to* resumes, nothing points to imports), then `.where(created_at: ...cutoff).where.not(extracted_text: nil).update_all(extracted_text: nil)`.
  - Do NOT touch `cv_generations.metadata.pdf_data`: generated PDFs are the user's own documents and stay until the account is deleted (lead decision).
- `test/jobs/data_retention_job_test.rb` (new)

**U5. Logs, Sentry, PostHog, SES** (one engineer, files not owned by anyone else). Independent.
- Replace the email/CV content with `user_id` / `.size` / counts at: `packs/accounts/app/jobs/send_otp_email_job.rb:13,16` (use the OTP record id); `packs/ai_tools/app/controllers/cv_generations_controller.rb:62,79,90,493`; `packs/ai_tools/app/controllers/api/translations_controller.rb:241`; `packs/resume_builder/app/controllers/resumes_controller.rb:126`; `packs/admin/app/services/batch_email_service.rb:73`; `packs/ai_tools/app/jobs/cv_generator_job.rb:56,145,146,162,208`; `packs/ai_tools/app/services/cv_generator/result_persister.rb:20,31` (log counts or delete the debug line). Grep the same files for other `.email}`/`.inspect` content logs and fix those too.
- `config/initializers/sentry.rb`: `config.send_default_pii = false`. `app/frontend/lib/sentry.js` already leaves it off, so no change there.
- `config/initializers/posthog.rb:33`: `capture_user_context = false`. Gating exceptions on the per-request cookie is not feasible in the Rails auto-capture, so turn the user context off.
- `packs/accounts/app/services/amazon_ses_service.rb:10`: remove `ssl_verify_peer: false` and its comment.
- No new tests required. Existing suites must stay green.

**U6. Docs** (`docs/pdpl.md`, new, English). Independent.
- Record of processing activities table: data category, purpose, legal basis, processor, location, retention (same numbers as U4). Then the consent record (fields and version), data-subject request handling (export/delete/email, 30-day answer), and a breach procedure: detect and contain, assess within 24 h, notify SDAIA within 72 h of awareness, notify affected users without undue delay, keep a breach log. Leave other docs alone.

Retention numbers (U2, U4 and U6 must match): OTP codes 1 day; failed analyses/imports deleted after 30 days; extracted CV text cleared after 30 days; generated PDFs kept with the account (the user's own documents); account data until the user deletes the account; credit ledger and purchases deleted with the account (payment records stay with Moyasar); server logs per host rotation.

## 4. Data

- One migration (U1): `add_column :users, :privacy_accepted_at, :datetime` and `add_column :users, :privacy_policy_version, :string`. Both are nullable with no default, so it is backwards compatible: existing users have nulls and the old code ignores the columns. It is reversible via `change`.
- No schema change for coupons (a model on the existing table only).
- The retention job mutates data on its own schedule: test it locally/test DB only. Never run it by hand against production in this work.

## 5. Tests (all in `test/`, minitest + fixtures)

- U1 `auth_controller_test.rb`: send_otp without `privacy_consent` redirects to login with the alert and creates no `OtpVerification`; with it, it enqueues `SendOtpEmailJob`; verify_otp with `privacy_consent=1` sets `privacy_accepted_at` and `privacy_policy_version == PrivacyPolicy::VERSION` (new and existing user). Update existing send_otp tests to pass the flag.
- U2 `pages_controller_test.rb`: `/privacy` in ar and en renders, contains `privacy@cvcrft.com`, SDAIA, the version date, and no "OpenAI"; `/terms` links to `/privacy`.
- U3 `profiles_controller_test.rb`: export redirects when signed out; signed in it returns `application/json` attachment named `seera-data-YYYY-MM-DD.json`, includes the user's resume title, has no `encrypted_password`/`pdf_data`. Destroy with a `CvImport` whose `resume_id` points at the user's resume, a `coupon_redemptions` row (insert a `coupons` row via SQL), and an `OtpVerification` for the email: the user is gone, the redemption and OTP are gone, the Redis/memory store no longer has the user, no PostHog event carries the email.
- U4 `data_retention_job_test.rb`: old/new OTPs; old failed vs old completed vs new failed records; extracted_text cleared only on old rows; cv_generations untouched.

## 6. Risks and checks

- **Packwerk**: `bin/packwerk validate && bin/packwerk check` (CI job `.github/workflows/ci.yml:56-69`). The risk is `UserDataExport` naming `Resume`/`WorkExperience`; keep it to associations. Do not add to `package_todo.yml`.
- **Existing login tests/system tests** post `send_otp` without consent and will fail. U1 updates them (`grep -rn send_otp test/`).
- **`has_one :linkedin_import` + `has_many :linkedin_imports`** on Resume: run `test/models/resume_test.rb` and the imports tests.
- **Deletion transaction**: `user.destroy!` runs `dependent: :destroy` callbacks (e.g. any in `CvGeneration`/`AiTranslation`). Run the profiles and model suites. The Redis cleanup runs after commit, so a Redis outage leaves a dangling id (harmless; ids are not reused).
- **SES TLS** now verifies peers. In dev on macOS this may need the system CA bundle; production Linux is fine. Check by sending an OTP in staging/dev.
- **sidekiq-cron** loads only in the server process. Check `bin/rails runner 'require "sidekiq/cron"'` and Sidekiq Web's Cron tab in dev.
- **Brakeman**: `send_data` with user-derived filename (date only, safe). Run `bin/brakeman --no-pager`.
- Full CI: `bin/rubocop`, `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/packwerk validate && bin/packwerk check`, `bin/rails db:test:prepare test test:system`.
- Nothing in this plan touches production data, credentials or `config/deploy.yml` secrets.
