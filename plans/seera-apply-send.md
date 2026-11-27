# Seera Apply, steps 2 and 3: apply to jobs for the user

Pack: `packs/job_applications` (step 1 is on this branch, see `plans/seera-apply.md`). Ideas, not code,
come from `origin/claude/project-thread-6w4uxh` (`answerer.rb`, `cover_letter.rb`, `application.rb`; read
them with `git show`, never merge them). Testers only: every new route, job and cron stays behind
`JobApplications.enabled_for?` / `enabled_anywhere?`.

## 1. Goal

A tester opens `/my-jobs` and taps **Apply for me**. A setup page asks six things (nationality,
visa/Iqama status, notice period, expected monthly salary in SAR (optional), phone, LinkedIn URL) and one
consent checkbox ("Seera sends my CV and these answers to employers I match with"). Then the switch
reads **On**, with **Pause** next to it.

From then on, every new match with a score of 8 or more gets an apply pack: a CV PDF where only the
professional summary is rewritten for the job, plus answers to the employer's form. The tracker on
`/my-jobs` has five tabs with counts: **Queued**, **Needs approval**, **Needs answer**, **Sent**, **Failed**.

- The first 3 applications wait in Needs approval with **Approve** / **Skip** and a link to the PDF.
- A question Seera can't answer from the CV or the six answers (EEO, salary when none was given, consent
  boxes, anything unknown) puts that application in Needs answer, with the question shown on the card.
- After 3 sent, applications go out on their own, at most 5 a day. Pause stops them.
- Sent shows the date and a "Proof" link (a screenshot of the employer's confirmation page, or the
  sent email). Failed shows "Open job page" and the CV download. Nothing failed is charged.
- Each sent application costs 5 credits. The first 3 are free.

All of it is in Arabic and English. The email to the employer is English only.

## 2. Approach

**One `Application` row per (user, posting), moved by four jobs.** `QueueJob` creates rows for new
good matches. `PrepareJob` builds the pack. `SendJob` claims a row, submits it and charges for it.
`DispatchJob` runs on a cron and picks up queued rows that a cap or pause held back. Every status
write is a conditional update or happens under `profile.with_lock`, following the rules at the top of
`docs/state-machines.md`.

**Two-phase submit.** A browser is slow, costly and fragile, so it only does the final fill and submit.
The questions are read over HTTP from the same public JSON the ATS page loads:

- Greenhouse: `boards-api.greenhouse.io/v1/boards/{token}/jobs/{id}?questions=true`
- Ashby: `jobs.ashbyhq.com/api/non-user-graphql?op=ApiJobPosting` (`applicationForm`)
- Lever: the `/apply` HTML, parsed with Nokogiri
- Workable: `apply.workable.com/api/v1/accounts/{acct}/jobs/{code}/form`

So the pack, its answers and any "needs answer" question are ready before a browser starts.
The browser step then only fills fields whose ids it already knows. If it finds a required field it
doesn't know, it stops before clicking Submit. Nothing is guessed at send time.

**Charge after confirmation, never before.** Repo rule 5 is "charge, then refund on failure". It
doesn't fit here: free uses are never given back, so a failed send would cost the user one of their 3
free sends. Instead:

1. `UsageGate.available?` is a read-only check that runs when the row is claimed.
2. `UsageGate.allow!(user, :job_application, key: "job_application:<id>")` runs only after the row
   is `sent` and committed.
3. A sent row whose charge didn't happen (for example a crash between steps) is charged later by the
   sweeper with the same key. The key is idempotent, so nothing is charged twice.

Only one row per user can be `sending` at a time (claimed under the profile lock), so the check in
step 1 can't be overtaken by another send. When billing is off for a user, `allow!` gives the first 3
as `:free`, then `available?` is false and rows wait with `hold: "no_credits"`. This is the same as
every other feature.

**Browser: Ferrum and Debian's `chromium`, not Playwright.**

- Ferrum is a pure-Ruby driver for the Chrome DevTools protocol, so the runtime image needs no Node.
  Today Node is only in the build stage.
- Playwright would add Node, its own browser download (about 400 MB) and a second process to keep alive.
- Chromium starts once per application and is closed afterwards, so memory is bounded (about 300 MB
  while it runs). It never runs as a long-lived pool.
- One global slot (Redis `SET NX EX 300`) means at most one Chromium runs on the host, whatever
  `SIDEKIQ_CONCURRENCY` is set to.
- Jobs run on their own Sidekiq queue, `apply_browser`, with weight 1.
- Chromium is started through `bin/chromium-clean`, which runs `env -i`, so the browser never
  inherits `RAILS_MASTER_KEY` or the AWS keys.
- Navigation is limited to an allowlist of ATS hosts (Ferrum's URL allowlist option). Those hosts and
  their asset CDNs are listed per submitter.

**The tailored CV is built inside this pack and drawn by resume_builder.** Reusing `CvGenerator` would
have three costs:

- it creates `CvGeneration` rows, which uses up the user's job-based generation allowance and adds
  rows to "My CVs";
- it asks the model to echo back the whole CV;
- it needs a `Resume` object, which crosses resume_builder's privacy boundary.

Instead, `TailoredSummary` sends one prompt with the same summary rules as `CvGenerator::PromptBuilder`
(its five `base_requirements` lines, copied). The rest of the CV never goes through the AI.
`ResumeBuilder::PublicApi.pdf(user, resume_id, professional_summary:)` draws the user's own resume with
only the summary swapped. So "only the summary is rewritten" is guaranteed by the code's structure,
not by asking the model nicely.

**Proof is stored in Postgres (`apply_documents`, bytea), not Active Storage.** This is owner decision 1.

- Active Storage is off in this app (its railtie is commented out in `config/application.rb`, and it
  has no tables).
- Production has no persistent storage volume (`config/deploy.yml`).
- Active Storage attachments are polymorphic and have no foreign key. Deleting an account cascades by
  foreign key (`user.destroy!`, see the step-1 PDPL notes) and skips `dependent: :purge`, so the
  screenshots, which show the user's name, phone and email, would be left on disk.
- A bytea row cascades with the user, is included in database backups (`docs/restore.md`), and matches
  how CV PDFs are already kept (`metadata["pdf_data"]`).
- Size cap: JPEG at quality 60, at most 1 MB, plus at most 2 MB of CV PDF per application.

## 3. Work units

Unit 1 lands first (it holds every migration, so `db/schema.rb` has one owner). Units 2 to 5 then run in
parallel: each codes against the interfaces fixed below and stubs the others in tests. No file is in
two lists.

### Unit 1: data, state machine, billing, jobs (no dependencies)

Owns:
- `db/migrate/20261128000100_create_seera_apply_send_tables.rb`, `db/migrate/20261128000200_add_job_applications_count_to_users.rb`, `db/schema.rb`
- `packs/job_applications/package.yml` (add `packs/billing`)
- `packs/job_applications/app/services/job_applications.rb` (constants, `export_for`)
- `packs/job_applications/app/models/job_applications/{profile,application,document,disclosure}.rb` (new), `ai_usage.rb` (add `packs` counter)
- `packs/job_applications/app/services/job_applications/{sender,channel,browser_slot}.rb`, `submitters.rb` (registry and `Result` only)
- `packs/job_applications/app/jobs/job_applications/{queue_job,prepare_job,send_job,dispatch_job}.rb`, `match_job.rb` (one line)
- `packs/billing/app/services/billing/usage_gate.rb` (one `COSTS` entry and one `REASONS` entry)
- `packs/accounts/app/services/user_usage_limits.rb` (the `job_application` kind)
- `packs/ai_tools/app/jobs/stale_work_sweeper_job.rb` (`MODEL_NAMES` += `"JobApplications::Application"`)
- `config/schedule.yml` (add `seera_apply_dispatch`), `config/sidekiq.yml` (add `[apply_browser, 1]`)
- `packs/README.md` (dependency line), `docs/state-machines.md` (section in §6)
- `test/support/seera_apply_helper.rb` (add `create_profile`, `create_application`)

Interfaces the other units code against:

```ruby
# job_applications.rb
APPLY_MIN_SCORE = 8; DAILY_SEND_LIMIT = 5; DAILY_PACK_LIMIT = 10; APPROVALS_REQUIRED = 3
CONSENT_VERSION = "2026-11-28"
SUBMITTERS = %w[greenhouse ashby].freeze   # lever, workable join after a live tester run passes
def self.dry_run? = ENV["SEERA_APPLY_DRY_RUN"] == "true"   # fill and screenshot, never click Submit

# Profile (apply_profiles)
VISA_STATUSES = %w[saudi_citizen gcc_citizen iqama_transferable iqama_not_transferable needs_sponsorship]
NOTICE_PERIODS = %w[immediate two_weeks one_month two_months three_months]
STATES = %w[off on paused]
def consented? ; def sending? = state == "on" && consented?
def give_consent!  # sets consent_version, consented_at, state "on"
def turn_off!      # state "off", consent cleared (withdrawal; turning on again asks for consent again)

# Application (apply_applications)
STATUSES = %w[preparing needs_answer needs_approval queued sending sent failed_fallback skipped]
TERMINAL = %w[sent failed_fallback skipped]
ERROR_CODES = %w[unsupported no_form captcha unknown_field timeout closed unconfirmed prepare_failed send_error dry_run]
HOLDS = %w[paused daily_cap no_credits]                     # only on queued rows
def transition!(from:, to:, **attrs) -> Boolean             # where(id:, status: from).update_all(...) == 1
def finish_pack!(questions:, answers:, missing:, summary:, cover_letter: nil)  # preparing -> needs_answer | needs_approval | queued
def answer!(values)        # needs_answer -> needs_approval | queued; remembers non-sensitive answers on the profile
def approve! ; def skip!   # needs_approval -> queued (enqueues SendJob) ; needs_approval|needs_answer|queued -> skipped
def fallback!(code)        # any non-terminal -> failed_fallback
def self.fail_stale!(older_than:) -> Integer  # sweeper, see section 6
def self.purge_old!                            # docs of terminal rows older than 90 days; called by Unit 4's fetch job

# submitters.rb
Result = Data.define(:outcome, :proof_bytes, :proof_type, :confirmation)  # outcome: :sent | :fallback ; confirmation: {url:, text:, message_id:, error_code:}
class Retryable < StandardError; end   # raised only before Submit is clicked
def self.for(application) -> submitter class or nil   # {"greenhouse"=>"JobApplications::Submitters::Greenhouse", ..., "email"=>"...::Email"}.safe_constantize
# each submitter class: .questions(posting) -> [Question hash] ; #initialize(application, cv_pdf:) ; #call -> Result
# Question hash: {"id","label","type"(text|textarea|select|radio|checkbox|file|email|tel|url|number),"options"=>[],"required"=>bool,"section"=>"main"|"eeo"}
```

Jobs, all `ApplicationJob`, all take the record id and return early on a terminal row:
- `QueueJob.perform(user_id)`. It runs after `Matcher#call` (MatchJob adds `QueueJob.perform_later(user.id)`
  after it matches each user) and returns unless `profile&.sending?`. It takes `Match.shown`
  rows with score ≥ `APPLY_MIN_SCORE` that have no application, puts browser and email channels first,
  takes at most `DAILY_PACK_LIMIT - AiUsage packs today`, and inserts them with
  `insert_all(unique_by: [user_id, posting_id])` as `preparing` with `channel = Channel.for(posting)`
  (`"browser"` if `employer.ats` is in `SUBMITTERS`, else `"email"` if `posting.apply_email`, else
  `"manual"`). It enqueues one `PrepareJob` per inserted row.
- `PrepareJob.perform(application_id)`, queue `default`. It calls `PackBuilder.new(app).call` (Unit 2)
  then `finish_pack!`. A `manual` row gets its PDF and then `fallback!("unsupported")`.
  `retry_on AiCircuit::OpenError, wait: AiCircuit.retry_delay, attempts: 5` and
  `retry_on StandardError, attempts: 3`. When the attempts run out it calls `fallback!("prepare_failed")`.
  Rows stay `preparing` between attempts.
- `SendJob.perform(application_id)`, queue `apply_browser`. For the browser channel it first gets
  `BrowserSlot.acquire`; if the slot is busy it calls `self.class.set(wait: 1.minute).perform_later(id)`
  and returns. Then `Sender.new(app).call`:
  1. `claim!` under `profile.with_lock`:
     - a closed posting gets `fallback!("closed")`;
     - `hold` is set and the row stays `queued` when the profile is paused (unless `approved_at` is set),
       when 5 were already sent or sending today (Asia/Riyadh), when another row of this user is
       `sending`, or when `UsageGate.available?` is false;
     - otherwise `queued → sending` with `claimed_at` and `attempts += 1`.
  2. Write a `Disclosure` row.
  3. Load the `cv_pdf` document.
  4. Call the submitter. Submitters set `submit_clicked_at` (conditional update) just before they click.
  5. `:sent`: in one transaction, `sending → sent`, set `sent_at` and `confirmation`, and save the
     `proof` document. After commit, `charge!`.
  6. `:fallback`: `fallback!(error_code)`, then mark the disclosure `outcome`.
  7. `Retryable` before the click: back to `queued`, or `fallback!("timeout")` once `attempts >= 3`.
     Any other error after the click: `fallback!("unconfirmed")`. It is never retried.
- `Sender#charge!`: `allow!(user, :job_application, key: "job_application:#{id}")` and stores `charge`
  (`free`/`credit`/`uncollected`). `:blocked` after a confirmed send is logged to Sentry, not undone.
- `DispatchJob.perform`, cron `*/15 * * * *`. It returns unless `enabled_anywhere?`, then enqueues one
  `SendJob` per user for that user's oldest `queued` row (`approved_at` rows first). This also paces the sends.
- Billing: `COSTS[:job_application] = 5`, `REASONS[:job_application] = "overage_job_application"`.
  `UserUsageLimits`: `BASE_JOB_APPLICATIONS = 3`, `COUNTERS[:job_application] = :job_applications_count`,
  `max_/used/remaining_job_applications`, and a branch in `free_available?` and `remaining_for`.
- Approval rule: `finish_pack!` picks `needs_approval` while
  `Application.where(user:, status: "sent").count < APPROVALS_REQUIRED`.
- `export_for(user)` adds `"profile"`, `"applications"` (attributes without documents) and `"disclosures"`.

Gate 1: migrate, rollback and migrate again cleanly; Unit 1 tests green; `bin/packwerk validate && bin/packwerk check`.

### Unit 2: apply pack (CV and answers). Depends on Unit 1's models

Owns:
- `packs/job_applications/app/services/job_applications/{pack_builder,tailored_summary,answerer,profile_answers,sensitive,cover_letter}.rb`
- `packs/resume_builder/app/public/resume_builder/public_api.rb` (add `pdf`), `packs/resume_builder/app/services/resume_pdf_service.rb` (a `professional_summary:` option)

```ruby
ResumeBuilder::PublicApi.pdf(user, resume_id, professional_summary: nil) -> {"filename"=>String, "data"=>String(binary)}
PackBuilder.new(application).call  # writes cv_pdf Document; returns {questions:, answers:, missing:, summary:, cover_letter:}
TailoredSummary.new(user, resume_id, posting).call -> String      # English, 3-4 sentences, falls back to the resume's own summary if the reply has Arabic or is blank
Answerer.new(application, profile:, facts:).call(questions) -> {answers: {id=>value}, missing: [id]}
ProfileAnswers.match(question, profile:, contact:) -> value | :sensitive | nil
Sensitive.match?(label) -> Boolean
```

- PackBuilder steps:
  1. Get the questions from `Submitters.for(app).questions(posting)` (empty for email and manual).
  2. Write the summary and the PDF (one AI call).
  3. Answer the questions: `ProfileAnswers` first, which is deterministic; then `profile.saved_answers`
     where the normalized label matches exactly; then a single `Answerer` AI call over the remaining
     non-sensitive questions. That AI call uses `CvFacts` and profile facts only, and its prompt is
     ported from the branch. Ruby enforces the options, as the branch did.
  4. Bump `AiUsage.packs` once.
- What `ProfileAnswers` fills:
  - first and last name, email and city come from `PublicApi.read` (the resume header);
  - phone and LinkedIn come from the profile;
  - nationality questions ("Saudi national?" yes/no);
  - visa, sponsorship and Iqama questions, only when the label names Saudi Arabia, KSA or Iqama, or names
    no country. Another country goes to `missing`;
  - notice period;
  - salary, only when it is given, the currency is SAR or not stated, and the period is monthly or yearly
    (×12). Anything else goes to `missing`;
  - the resume file field is filled with the PDF. A cover letter is left out when it is optional; when it
    is required it is generated by `CoverLetter`, ported, from CV facts.
- Sensitive questions are EEO, gender, race, religion, disability, veteran status, criminal record,
  marital status, consent and legal statements (English and Arabic regex, extending the branch's). They
  are never sent to the AI. A required one goes to `missing`; an optional one is left blank (owner
  decision 3).
- `missing` = required questions that are still unanswered.

Gate 2: Unit 2 tests green; the `CvGenerator` prompt fixtures are unchanged (`test/fixtures/files/cv_generator/*.txt`).

### Unit 3: browser submitters and the Docker image. Depends on Unit 1's contract only

Owns:
- `Gemfile`, `Gemfile.lock` (`gem "ferrum"`, the current release at least 2 weeks old, pinned with `~>`), `Dockerfile`, `bin/chromium-clean` (new, mode 755)
- `packs/job_applications/app/services/job_applications/submitters/{base,browser,greenhouse,ashby,lever,workable}.rb`
- `test/fixtures/files/ats_forms/*`

- `Submitters::Browser.open { |page| ... }` starts a `Ferrum::Browser` with:
  `browser_path: ENV.fetch("CHROMIUM_PATH", "/rails/bin/chromium-clean")` (falls back to Ferrum's own
  detection when that path is missing, as in dev and CI), `headless: "new"`, `timeout: 30`,
  `process_timeout: 20`, `window_size: [1280, 2000]`, a fresh `user-data-dir` under `Dir.mktmpdir`,
  options `no-sandbox`, `disable-dev-shm-usage`, `disable-gpu`, and the allowlist from `self.class::HOSTS`.
  It always calls `quit` and removes the temp dir in `ensure`. The whole run is limited to 120 s.
- `Base#call`:
  1. `goto` the form.
  2. Check that every required field on the page is in `application.answers` (or is the CV file field).
     If one isn't, the result is `Result(:fallback, error_code: "unknown_field")` and Submit is not clicked.
  3. Fill the fields and attach the PDF with `select_file` from a tempfile.
  4. With `dry_run?`, take a screenshot and return `fallback dry_run`.
  5. Otherwise set `submit_clicked_at`, click Submit, then wait up to 45 s for `confirmed?`.
  - A visible captcha frame (`hcaptcha.com`, `google.com/recaptcha/api2/bframe`, `challenges.cloudflare.com`)
    gives `fallback captcha`.
  - No confirmation gives `fallback timeout`.
  - `Ferrum::TimeoutError` or `DeadBrowserError` before the click raises `Retryable`.
  - The proof is `page.screenshot(format: "jpeg", quality: 60, full: true)`.
- Per ATS (`HOSTS`, `.questions(posting)`, `form_url`, `fill(page, question, value)`, `confirmed?(page)`):
  - Greenhouse: questions from `boards-api ... ?questions=true`, including `location_questions`,
    `compliance` and `demographic_questions` as section `eeo`. Form at
    `job-boards.greenhouse.io/embed/job_app?for={token}&token={id}`. Its selects are React comboboxes:
    click, type, Enter. Confirmed when the URL matches `/confirmation` or the text says "Thank you for applying".
  - Ashby: questions from `applicationForm.sections[].fieldEntries[].field` (`path`, `title`, `type`,
    `isNullable`, `selectableValues`). Form at `jobs.ashbyhq.com/{org}/{id}/application`; inputs are found
    by `name=path`. The confirmed selector is taken from the fixture.
  - Lever and Workable are the same shape, and stay out of `SUBMITTERS` until a tester run passes.
    Lever's apply page usually has hCaptcha, which gives a `captcha` fallback.
- Questions are read over plain `Net::HTTP` inside `Submitters::Base` (5 s to open, 20 s to read, the same
  User-Agent as the fetchers). The fetchers are left as they are.
- Dockerfile, final stage only, before `USER`:
  ```dockerfile
  # Seera Apply browser submitters (packs/job_applications): headless Chromium driven by Ferrum.
  RUN apt-get update -qq && \
      apt-get install --no-install-recommends -y chromium fonts-liberation fonts-dejavu-core && \
      rm -rf /var/lib/apt/lists /var/cache/apt/archives
  ```
  `bin/chromium-clean`: `#!/bin/sh` then `exec env -i PATH=/usr/bin:/bin HOME=/tmp LANG=C.UTF-8 /usr/bin/chromium "$@"`.
  Budget: the image grows by at most 350 MB (`docker image ls` before and after; write the number in the PR).

Gate 3: Unit 3 tests green locally, with Chrome present, so the fixture fills run; `docker build .` succeeds;
`docker run --rm <img> /rails/bin/chromium-clean --headless=new --dump-dom about:blank` prints HTML.

### Unit 4: email channel. Depends on Unit 1

Owns:
- `packs/job_applications/app/services/job_applications/{apply_email,submitters/email}.rb`
- `packs/job_applications/app/jobs/job_applications/fetch_postings_job.rb` (sets `apply_email` and calls `Application.purge_old!` in `clean_up`)
- `packs/job_applications/app/views/job_applications/emails/application.text.erb`
- `packs/accounts/app/services/amazon_ses_service.rb` (add `send_raw`)

```ruby
ApplyEmail.from(description) -> String | nil   # first mailto, or an address within 80 chars of apply|cv|resume|send|تقديم|السيرة; no-reply/noreply and image-like addresses dropped
AmazonSesService#send_raw(mail) -> message_id  # Aws::SES::Client#send_raw_email(raw_message: {data: mail.to_s})
Submitters::Email#call -> Result               # .questions(posting) = []
```

- The message is built with `Mail.new`:
  - From `"<Name> via Seera <#{credentials.aws[:from_email]}>"`; Reply-To the user's email; To `posting.apply_email`;
    Cc the user (owner decision 6).
  - Subject `"Application: <title> – <name>"`.
  - Body from the text template: the summary, notice period, visa status, salary if given, phone and LinkedIn.
  - The CV PDF is attached.
- An SES `MessageId` means `:sent`. The proof is the rendered `.eml` text (`proof_type: "message/rfc822"`).
  An SES error is `Retryable`; nothing is "clicked", so `submit_clicked_at` is set only once SES returns.
- The fetch upsert adds `apply_email: ApplyEmail.from(p.description)` to each row and to `update_only`.

Gate 4: Unit 4 tests green; the step-1 fetch tests still pass.

### Unit 5: UI, copy, consent, privacy. Depends on Unit 1

Owns:
- `config/routes.rb` (inside the existing `my-jobs` scope)
- `packs/job_applications/app/controllers/job_applications/{profiles_controller,applications_controller}.rb` (new), `dashboard_controller.rb`
- `packs/job_applications/app/views/job_applications/dashboard/{show.html.erb,_tracker.html.erb,_application_card.html.erb,_question_field.html.erb}`
- `packs/job_applications/app/views/job_applications/profiles/edit.html.erb`
- `config/locales/seera_apply.en.yml`, `config/locales/seera_apply.ar.yml`
- `app/views/pages/privacy/_body_en.html.erb`, `_body_ar.html.erb`

Routes:

```ruby
get   "setup",   to: "profiles#edit",    as: :setup     # my_jobs_setup_path
patch "setup",   to: "profiles#update"
patch "sending", to: "profiles#sending", as: :sending   # params[:state] in on|paused|off
resources :applications, only: [] do
  member { patch :approve; patch :skip; patch :answer; get :cv; get :proof }
end
```

- Every action is scoped to `current_user`'s rows, so another user's id is a 404.
  - `answer` permits only the ids in `missing`.
  - `cv` and `proof` use `send_data`, `disposition: "inline"`, and the stored content type. A
    `message/rfc822` proof is served as `text/plain`.
  - `rate_limit to: 30, within: 1.minute` on the write actions.
- `/my-jobs`:
  - If the profile isn't set up, an "Apply for me" card sits above the count.
  - Otherwise the switch and the tracker sit above it: chips for On, Paused and Off, then five tab links
    with counts (`?tab=queued|approval|answer|sent|failed`). The default tab is the first non-empty one of
    answer, approval, queued.
  - Cards:
    - title, company, a status chip;
    - Needs approval: Approve, Skip, a CV link, and a `<details>` with the answers;
    - Needs answer: the questions, rendered by `_question_field` per type;
    - Sent: the date and Proof;
    - Failed: "Open job page" (`target=_blank rel=noopener noreferrer`) and the CV link;
    - Queued with a hold: one short label (paused, daily cap, or no credits, which links to `/credits`
      only when `Billing.enabled_for?`).
  - It uses the same Seera glass classes as step 1, with no helper text.
- Setup form: the six fields, then the consent checkbox with the consent text. Under the text is one
  line stating the data categories and that employers' hiring systems may be hosted outside Saudi Arabia.
  Phone is validated as `+?[0-9 ]{8,16}`; LinkedIn must be https on `linkedin.com`.
- Copy: new keys under `seera_apply.apply.*`, `seera_apply.setup.*`, `seera_apply.status.*`,
  `seera_apply.hold.*`, `seera_apply.errors.*` (one per error code), in both `en` and `ar`.
- Privacy page (en and ar, the same places): a paragraph on sending to employers, when the user turns it
  on (purpose, categories, recipients, transfer outside Saudi Arabia, the disclosure log, withdrawing by
  turning it off). Leave `PrivacyPolicy::VERSION` alone until public launch; consent is captured per
  feature with `CONSENT_VERSION`.

Gate 5: Unit 5 tests green; a manual check in `bin/dev` in both locales at 375 px and in RTL.

## 4. Data

`20261128000100_create_seera_apply_send_tables.rb` (`Migration[8.1]`). It creates new tables, adds two
nullable or constant-default columns to step-1 tables, and adds no index on an existing large table.
That passes strong_migrations with `target_version 17`. Old code ignores everything it adds.

| Table / change | Columns |
|---|---|
| `apply_profiles` | `user` ref null:false, unique index, FK cascade; `nationality` string; `visa_status` string; `notice_period` string; `expected_salary_sar` integer; `phone` string; `linkedin_url` string; `state` string null:false default `"off"`; `consent_version` string; `consented_at` datetime; `saved_answers` jsonb null:false default `{}`; timestamps |
| `apply_applications` | `user` ref null:false (no single index) FK cascade; `posting` ref null:false FK `apply_postings` cascade; `status` string null:false default `"preparing"`; `channel` string null:false; `approval_required` bool null:false default false; `approved_at` datetime; `questions` jsonb null:false default `[]`; `answers` jsonb null:false default `{}`; `missing` jsonb null:false default `[]`; `summary` text; `cover_letter` text; `hold` string; `error_code` string; `attempts` integer null:false default 0; `claimed_at`, `submit_clicked_at`, `sent_at` datetime; `charge` string; `confirmation` jsonb null:false default `{}`; timestamps. Unique `[user_id, posting_id]`; indexes `[user_id, status]`, `[status, updated_at]` |
| `apply_documents` | `application` ref null:false FK `apply_applications` cascade; `kind` string null:false (`cv_pdf`/`proof`); `content_type`, `filename` string null:false; `byte_size` integer null:false; `data` binary null:false; timestamps. Unique `[application_id, kind]` (no single index) |
| `apply_disclosures` | `user` ref null:false FK cascade; `application_id` bigint, no FK (it outlives the posting cleanup); `employer_name`, `channel`, `recipient` (host or email) string null:false; `data_categories` string array null:false; `consent_version` string null:false; `outcome` string; timestamps. Index `[user_id, created_at]` |
| `apply_ai_usages` | `add_column :packs, :integer, null: false, default: 0` |
| `apply_postings` | `add_column :apply_email, :string` |

`20261128000200_add_job_applications_count_to_users.rb` adds `users.job_applications_count integer
null:false default 0`. A constant default is a metadata-only change on PG 11 and later, with no rewrite
and no long lock.

Retention and PDPL:
- Account deletion cascades through every foreign key above, so `User` gets no new associations.
- `Application.purge_old!` deletes the documents of terminal rows older than 90 days, and clears
  `answers` and `cover_letter` on rows older than 180 days.
- Postings deleted by the step-1 90-day cleanup cascade to their applications. Disclosures stay for the
  life of the account, and the data export includes them.

## 5. Tests (all under `test/`; the browser and HTTP are always stubbed except in the fixture fill tests)

Unit 1:
- `test/models/job_applications/application_test.rb` covers:
  - every allowed transition, and that a disallowed one returns false;
  - `finish_pack!` routes to needs_answer, needs_approval or queued;
  - `approve!` enqueues `SendJob`;
  - `fail_stale!`: stale preparing goes to fallback; stale sending with no click goes back to queued, or to
    fallback when attempts are used up; clicked goes to `unconfirmed`; a sent row with no charge gets charged;
  - `purge_old!`.
- `test/models/job_applications/profile_test.rb`: validations; `give_consent!` stores the version and
  time; `turn_off!` clears consent.
- `test/services/job_applications/sender_test.rb` covers:
  - each claim hold (paused, daily cap of 5 in Riyadh time, a second sending row, no credits with billing off);
  - an approved row goes out while paused;
  - a confirmed send charges 5 credits once, even when called twice with the same key;
  - the first 3 are `:free` and bump `job_applications_count`;
  - a fallback charges nothing and leaves the counter alone;
  - `Retryable` goes back to queued;
  - an error after the click gives `unconfirmed` with no charge;
  - one disclosure row per attempt;
  - a closed posting falls back.
- `test/jobs/job_applications/{queue_job,prepare_job,send_job,dispatch_job}_test.rb`:
  - QueueJob respects the threshold, consent, `sending?`, the daily pack limit and the channel choice;
  - PrepareJob gives `prepare_failed` once retries are used up, and a manual row ends `unsupported`;
  - SendJob re-enqueues when the slot is busy;
  - every job is a no-op on a terminal row and when the gate is off.
- `test/services/billing/usage_gate_test.rb` (extend): `job_application` costs 5, is blocked when billing
  is off past 3, and `quote` includes it.
- `test/services/user_usage_limits_test.rb` (extend or create): base 3, and unlimited coupons.
- `test/jobs/stale_work_sweeper_job_test.rb` (extend): includes applications.
- `test/services/user_data_export_test.rb` (extend): profile, applications and disclosures are present;
  `user.destroy!` removes every apply_* row.

Unit 2:
- `test/services/job_applications/profile_answers_test.rb`: name split, phone, LinkedIn, Saudi national
  yes/no, KSA visa answered, UAE visa missing, salary monthly and yearly, salary in USD missing, Arabic labels.
- `answerer_test.rb`: sensitive questions never reach the AI (`AiModel.expects(:complete)` with a prompt
  that doesn't contain them); options enforced; bad JSON leaves everything missing; required unknown
  goes to missing; optional unknown is blank.
- `tailored_summary_test.rb`: the prompt holds the job and the CV facts but no email or phone; an
  Arabic reply falls back.
- `pack_builder_test.rb`: writes `cv_pdf`; bumps `packs` once; uses saved answers.
- `test/services/resume_builder/public_api_test.rb` (extend): the `pdf` summary override changes only
  the summary text (checked with `PDF::Reader`), and another user's resume raises RecordNotFound.

Unit 3:
- `test/services/job_applications/submitters/{greenhouse,ashby,lever,workable}_test.rb`: `.questions`
  parsed from `test/fixtures/files/ats_forms/<ats>_questions.json` (or `.html`) with `Net::HTTP` stubbed.
  A fake page object (`FakePage`, in the test file) tests the fill mapping, unknown_field (no click),
  captcha, timeout, `Retryable` before the click, and dry_run (no click, screenshot taken).
- `test/integration/job_applications/browser_fill_test.rb`: real headless Chrome through Ferrum on
  `file://` fixtures `ats_forms/<ats>_form.html` (copies of the real markup with the scripts taken out;
  the form's action is `<ats>_confirmation.html`). It asserts that the fields are filled, the file is
  attached and `confirmed?` is true. It is skipped when no Chrome is found, except when `ENV["CI"]` is set
  (CI installs `google-chrome-stable`).

Unit 4:
- `test/services/job_applications/apply_email_test.rb`: mailto, nearby-keyword match, noreply dropped,
  nil when there is none.
- `test/services/job_applications/submitters/email_test.rb`: `AmazonSesService#send_raw` stubbed;
  checks the headers (From display name, Reply-To, Cc, To), the PDF attachment, an English body, and
  that the proof is stored.
- `test/jobs/job_applications/fetch_postings_job_test.rb` (extend): `apply_email` set; `purge_old!` called.

Unit 5:
- `test/controllers/job_applications/profiles_controller_test.rb`: 404 when the gate is off; consent is
  required to turn on; validation errors; `sending` changes state; off clears consent.
- `test/controllers/job_applications/applications_controller_test.rb`: approve, skip and answer move
  status; answer refuses ids that aren't in `missing`; another user's row is a 404; `cv` and `proof` send
  the bytes with the right type.
- `test/controllers/job_applications/dashboard_controller_test.rb` (extend): the setup card; each tab and
  its counts; the "Open job page" link on failed; renders in `ar`.
- `test/system/job_applications/apply_flow_test.rb`: setup, then approve a prepared application, then it
  shows in Queued (`SendJob` not run).

CI (every unit's last step, in this order):

```bash
bin/rails db:migrate && bin/rails db:rollback STEP=2 && bin/rails db:migrate   # local dev DB only
bin/packwerk validate && bin/packwerk check
bin/rubocop
bin/brakeman --no-pager
bin/importmap audit
bin/rails db:test:prepare test test:system
```

## 6. `docs/state-machines.md` (Unit 1 adds this after "Seera Apply fetch and match")

```markdown
## Seera Apply applications

`job_applications/app/models/job_applications/application.rb`: `apply_applications.status` (default
`preparing`), `hold`, `error_code`, `attempts`, `claimed_at`, `submit_clicked_at`, `charge`. One row per
(user, posting). Terminal: `sent | failed_fallback | skipped`. Gate: `JobApplications.enabled_for?`.

| From → to | Where |
|---|---|
| new → preparing | `QueueJob` (score ≥ 8, `profile.sending?`, `DAILY_PACK_LIMIT`), `insert_all` unique `[user_id, posting_id]` |
| preparing → needs_answer / needs_approval / queued | `finish_pack!` (missing required answers / fewer than 3 sent / otherwise) |
| preparing → failed_fallback | `unsupported` (manual channel, pack kept) or `prepare_failed` (retries exhausted) |
| needs_answer → needs_approval / queued | `answer!` |
| needs_approval → queued | `approve!` (sets `approved_at`, enqueues `SendJob`) |
| needs_* / queued → skipped | `skip!` |
| queued → sending | `Sender#claim!` under `profile.with_lock`; holds (`paused`, `daily_cap`, `no_credits`) keep it queued |
| sending → sent | confirmed submit or SES MessageId; then `charge!` (`UsageGate.allow!`, key `job_application:<id>`) |
| sending → queued | `Retryable` before Submit, `attempts < 3` |
| sending → failed_fallback | `captcha`, `unknown_field`, `timeout`, `closed`, `dry_run`, `unconfirmed` (error after the click) |

- Charge only after `sent` is committed. Nothing is ever charged on a failure, so there are no refunds.
  The first 3 are free (`UserUsageLimits` `job_application`); after that it costs 5 credits, or the row is
  held as `no_credits` while billing is off for the user.
- Never resubmit after `submit_clicked_at` is set.
- Jobs: `PrepareJob` (`default`, AI retries as in "AI breaker"), `SendJob` (`apply_browser`, one Chromium
  per host through `BrowserSlot`, Redis key `seera_apply:browser`, 300 s TTL), `DispatchJob` (`*/15`, one
  `SendJob` per user per run).
- Sweeper: `Application.fail_stale!(older_than: 30.minutes.ago)`:
  - `preparing` → `failed_fallback`/`prepare_failed`;
  - `sending` with no click → `queued` (or fallback `timeout` once attempts are used up);
  - `sending` after the click → `failed_fallback`/`unconfirmed`;
  - `sent` with `charge` nil → `charge!`.
- PDPL: one `apply_disclosures` row per send attempt, written before the submit.
```

## 7. Risks and checks

- **Double application.** A crash after the click must never resubmit. The `submit_clicked_at` checks
  and the sweeper's `unconfirmed` branch are tested; SendJob has no ActiveJob retry after the click.
- **Captchas and bot checks.** Greenhouse and Ashby may run invisible reCAPTCHA, and Lever and Workable
  often show hCaptcha or Turnstile. These end as `captcha`/`timeout` fallbacks with no charge. Run with
  `SEERA_APPLY_DRY_RUN=true` for the first tester week (owner decision 4) and log the share of each
  `error_code`. If the fallback share is high, the channel isn't worth its RAM.
- **Wrong answers sent under the user's name.** These are kept down by four things: deterministic
  answers first, Ruby enforcing the options, sensitive questions never sent to the AI, and approval for
  the first 3. `Answerer` tests pin each of these.
- **Billing.** Check the idempotent key, that the free counter is consumed only after a confirmed send,
  and that `UsageGate.quote` and the `available?` callers don't break when the new kind is added
  (`REASONS.fetch` raises for unknown kinds, so both maps need it). Run the whole billing test folder.
- **Sweeper.** `StaleWorkSweeperJob` runs every 10 minutes on every model in its list, so a bug in
  `fail_stale!` stops the sweep for CV generation too. Unit 1 tests the sweeper end to end.
- **Image size, RAM and security.**
  - Chromium adds about 300 MB to the image. Gate 3 measures it.
  - One browser per host, killed in `ensure`.
  - `no-sandbox` is needed in Docker as a non-root user. The risk is limited by the `env -i` wrapper, the
    host allowlist and the fresh profile per run. Brakeman doesn't look at any of this, so review it by hand.
- **SES.** Raw sends to employer addresses need SES production access and a verified From identity
  (owner decision 6). Reply-To is the user, so bounces and replies reach the user. Keep test sends to
  `example.com` stubs only.
- **Packwerk.** The new dependency on `packs/billing` goes in `package.yml` and `packs/README.md`.
  Resumes are reached only through `PublicApi.pdf` and `read`. Don't add to `package_todo.yml`.
- **schedule.yml.** Keep `data_retention`, `stale_work_sweeper`, `slo_check` and `seera_apply_fetch`
  as they are, because jobs missing from the file are deleted.
- **ATS markup drift.** The fixtures are snapshots, so a real change shows up as a rise in
  `unknown_field` fallbacks, not as a test failure. Add a line about it to `docs/runbook.md` (Unit 1 owns that line).
- **Off limits.** Nothing here touches production data, secrets, `config/deploy.yml` or
  `credentials`. The owner applies any deploy or SES change.

## 8. Owner decisions

1. **Proof storage.** Postgres bytea (recommended, reasons in §2) or Active Storage. Active Storage
   means turning on its railtie and install migration, adding a Kamal volume for `/rails/storage` in
   `deploy.yml`, backing up that volume, and purging attachments by hand when an account is deleted.
2. **Testers past 3 free sends.** With billing off, sends stop after 3 (`no_credits`). Put the testers in
   `BILLING_TESTERS` too, or give them the unlimited coupon, which also makes sends unlimited and free.
3. **Optional EEO and demographic questions.** Leave them blank (recommended) or pause the application on
   them too. Required ones always pause.
4. **Dry run first.** Start production with `SEERA_APPLY_DRY_RUN=true`: everything is filled and
   screenshotted, and Submit is never clicked. Recommended for one week.
5. **Score needed to auto-apply.** 8 (recommended) or step 1's display threshold of 7.
6. **Email channel.** The From identity: the existing SES `from_email`, or a new verified `apply@` sender.
   Whether to Cc the user (recommended). SES production access.
7. **Approve while paused.** Recommended: a tap on Approve sends even while paused; pause stops only
   automatic sends.
8. **Later.** A separate Kamal worker role (`sidekiq -q apply_browser -c 1`) instead of the Redis slot,
   once there is real traffic.
9. **Legal.** Automated submission may break an ATS's or an employer's terms. Have the consent text,
   the Arabic privacy paragraph and the cross-border statement reviewed before testers outside the team
   use this.

**Decided (2026-11-27, owner approved the flow; defaults chosen):** 1 Postgres bytea. 3 leave optional EEO blank. 4 `SEERA_APPLY_DRY_RUN` exists but defaults to off (the first 3 user approvals are the safety net). 5 score 8. 6 existing SES `from_email`, Cc the user. 7 Approve sends while paused. 2, 8, 9 are left to the owner after merge.
