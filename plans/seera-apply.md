# Seera Apply, step 1: daily job sync, matching and "Jobs for you"

Pack: `packs/job_applications` (new). Source to port: `origin/claude/project-thread-6w4uxh`
(read with `git show origin/claude/project-thread-6w4uxh:<path>`; do not merge or cherry-pick it).

## 1. Goal

A tester (and nobody else) signs in and sees **Jobs** in the site header. `/my-jobs` shows one big
number ("34 jobs match you" / "34 وظيفة تناسبك") and a list of matching open jobs: title, company,
city, score out of 10, and a link that opens the employer's job page. If they have no finished CV the
page links to the builder; if they have no preferences the page opens with a small form (job titles +
city chips: Riyadh, Jeddah, Dammam, Remote). Every day at 04:30 the server reads the public ATS feeds
of the 74 seeded employers and scores new jobs for each tester with AI, capped at 40 jobs per user per day.

Out of scope (later steps): sending applications, the browser extension, tokens/API, consent-to-send,
the 5-credit charge. No billing code is touched.

## 2. Approach

Port the read-side of the branch (fetchers, location parsing, title tokens, seeder, employer list)
almost unchanged, and replace its apply queue (`Application` with statuses, consent, modes, tokens)
with one slim `JobApplications::Match` row per (user, posting): the AI score and a one-sentence
reason. A match is written for every posting the AI scored, high or low, so a posting is never scored
twice; the page shows only `score >= MIN_SCORE` (7) on open postings. There is no status column, so
there is no state machine to guard beyond "scored once" (unique index) and a daily AI budget.

Why this beats the obvious alternative (merge the branch and hide the apply parts behind the flag):
the branch carries ~4,000 lines of extension, consent and apply-queue code, a migration whose version
collides with main, and privacy text that promises consent flows that would not exist. Shipping dead
apply code behind a flag means reviewing, securing (token API) and keeping it green for nothing. A slim
`Match` table is the only thing step 2 needs to add statuses to later (a new `apply_applications` table
can reference `apply_matches`), so nothing here has to be undone.

Matching is two-stage to keep AI cost bounded: `TitleTokens.overlap?` (free keyword prefilter on the
user's titles) and a city filter pick at most `remaining_budget` candidates, then `AiModel.complete`
scores them in batches of 5 (one call per batch, JSON reply). `AiModel.complete` already goes through
`AiCircuit`. The fetch job also re-runs `EmployerSeeder` at start, so `config/employers.yml` is the
source of truth and nobody has to run a rake task in production.

Gate: `JobApplications.enabled_for?(user)` copies `Coach.enabled_for?` with `SEERA_APPLY_ENABLED` and
`SEERA_APPLY_TESTERS`. `JobApplications.enabled_anywhere?` keeps the cron job a no-op until one of the
two is set. `config/deploy.yml` is not edited, so it is off everywhere by default.

## 3. Work units

One `software-engineer`, sequentially. Unit A must be green before Unit B starts (B renders A's data).
No other agent edits these files. Paths are repo-relative.

### Unit A: data, sync and matching (backend only)

Owns:

- `db/migrate/20261127000100_create_seera_apply_tables.rb` (new), `db/schema.rb` (regenerated)
- `packs/job_applications/package.yml`
- `packs/job_applications/config/employers.yml` (copy as-is, 74 entries)
- `packs/job_applications/app/services/job_applications.rb`
- `packs/job_applications/app/services/job_applications/{fetchers.rb,fetchers/base.rb,fetchers/greenhouse.rb,fetchers/lever.rb,fetchers/ashby.rb,fetchers/workable.rb,fetchers/smart_recruiters.rb,fetchers/workday.rb}` (copy as-is)
- `packs/job_applications/app/services/job_applications/{title_tokens.rb,employer_seeder.rb}` (copy; fix comments that say `auto_apply_*`)
- `packs/job_applications/app/services/job_applications/gulf_location.rb` (copy + `city_for`)
- `packs/job_applications/app/services/job_applications/{cv_facts.rb,matcher.rb}` (rewrite from branch)
- `packs/job_applications/app/models/job_applications/{employer.rb,posting.rb,preference.rb,match.rb,ai_usage.rb}`
- `packs/job_applications/app/jobs/job_applications/{fetch_postings_job.rb,match_job.rb}`
- `packs/resume_builder/app/public/resume_builder/public_api.rb` (add `latest_complete` only)
- `lib/tasks/job_applications.rake`
- `config/schedule.yml` (append one entry)
- `packs/accounts/app/services/user_data_export.rb` (one key + nothing else)
- `packs/README.md` (one table row + one dependency line)
- `docs/state-machines.md` (new section, see below)
- Tests: `test/support/seera_apply_helper.rb`, `test/fixtures/files/ats/*.json`, `test/fixtures/files/employers.yml`,
  `test/services/job_applications/*`, `test/models/job_applications/*`, `test/jobs/job_applications/*`,
  `test/services/user_data_export_test.rb` (add one test; create if it does not exist, check `test/` first)

Details:

- `JobApplications` module (`job_applications.rb`):
  `enabled_for?(user)` (Coach pattern, env `SEERA_APPLY_ENABLED` / `SEERA_APPLY_TESTERS`),
  `enabled_anywhere?`, `table_name_prefix = "apply_"`, `DAILY_SCORE_LIMIT = 40`, `MIN_SCORE = 7`,
  `CITIES = %w[riyadh jeddah dammam remote].freeze`, and
  `export_for(user) -> Hash` (`{"preference" => attrs or nil, "matches" => [attrs + {"posting" => {title, company, url, city}}]}`)
  so `UserDataExport` adds one line: `"seera_apply" => JobApplications.export_for(user)`.
  Drop `COUNTRIES`, `CONSENT_VERSION`, `DAILY_CAP_MAX`, `DAILY_ANSWER_LIMIT`, `today`.
- `package.yml`: `enforce_dependencies: true`, `enforce_privacy: false`, dependencies `"."`,
  `packs/accounts`, `packs/resume_builder`. (`AiModel` is in `config/initializers/ruby_llm.rb` and
  `AiCircuit` in `app/services`, both root.) Reach resumes only via `ResumeBuilder::PublicApi`.
- `ResumeBuilder::PublicApi.latest_complete(user)`: copy the branch's method verbatim (newest
  `not_drafts` by `updated_at desc, id desc`, returns `{"id","title","updated_at"}` or nil). Main
  already has `list`, `read`, `create_from_draft`; add nothing else.
- `GulfLocation.city_for(location) -> "riyadh" | "jeddah" | "dammam" | "remote" | nil`. Latin:
  riyadh; jeddah/jiddah; dammam/khobar/al khobar/dhahran (Eastern Province counts as dammam).
  Arabic (through `normalize`): الرياض; جدة; الدمام/الخبر/الظهران. A specific city wins over remote;
  "remote" when the text matches `/\bremote\b|عن ?بعد/i` (including "Remote - Saudi Arabia").
- `CvFacts.new(user, resume_id).to_prompt -> String`: keep the branch's `to_prompt` without the
  `contact:` option; delete `contact_details`, `profile`, `split_name`, `preference`. No name, email
  or phone leaves the app for matching.
- `Preference`: `belongs_to :user`; `titles` (≤10, each ≤80 chars), `cities` (subset of `CITIES`).
  `def ready? = titles.any? && cities.any?`.
- `Posting`: copy + `city` column; `has_many :matches, dependent: :delete_all`; scopes `open`, `fresh`.
- `Match` (`apply_matches`): `belongs_to :user`, `belongs_to :posting`; validates `score` in 1..10;
  `scope :shown, -> { where(score: MIN_SCORE..).joins(:posting).merge(Posting.open) }`.
- `AiUsage`: counters `%i[scores]` only; `bump!`, `remaining(user, limit)`.
- `Matcher.new(user).call -> Integer` (matches written):
  return 0 unless `preference&.ready?` and `PublicApi.latest_complete(user)` and budget > 0;
  `candidates` = `Posting.open.fresh.where(city: preference.cities).where.not(id: user's matched posting ids)`
  ordered by `posted_at DESC NULLS LAST, id DESC`, `limit(SCAN_LIMIT=2000)`, then `TitleTokens.overlap?`
  in Ruby, `.first(remaining)`; `each_slice(5)` → one `AiModel.complete(system:, user:, temperature: 0.2, max_tokens: 800)`
  per batch, parse with `AiModel.json_body`, `Match.insert_all(rows, unique_by: %i[user_id posting_id])`
  (score clamped 1..10, reason squished, 500 chars). Bump `AiUsage` by batch size **after** the call
  returns or raises a provider error; on `AiCircuit::OpenError` do not bump and re-raise so the job
  stops (no call was made). Parse errors log and return 0 for that batch.
- `FetchPostingsJob#perform`: return unless `enabled_anywhere?`; `EmployerSeeder.call`; fetch each
  active employer (branch code, add `city: GulfLocation.city_for(p.location)` to each upsert row and
  `city` to `update_only`); `clean_up` (closed postings older than 90 days delete with their matches;
  `AiUsage` older than 30 days); then `MatchJob.perform_later`.
- `MatchJob#perform(user_id = nil)`: with an id, match that one user; without, every `Preference`
  with titles and cities whose user passes `enabled_for?`. Per-user `rescue StandardError` → log +
  Sentry; `AiCircuit::OpenError` ends the whole run without Sentry (next daily run picks it up).
- `config/schedule.yml`: append, keeping `stale_work_sweeper` and `slo_check`:
  ```yaml
  # Seera Apply (packs/job_applications): reads public ATS job feeds, then scores
  # new jobs for testers. Returns at once unless SEERA_APPLY_ENABLED/TESTERS.
  seera_apply_fetch:
    cron: "30 4 * * *"
    class: "JobApplications::FetchPostingsJob"
    queue: default
  ```
- Rake: `job_applications:seed_employers` and `job_applications:fetch`, messages naming the new env vars.

Gate A: migrate + rollback + migrate clean; `bin/rails test test/services/job_applications test/models/job_applications test/jobs/job_applications test/services/user_data_export_test.rb` green; `bin/packwerk validate && bin/packwerk check` clean.

### Unit B: page, nav, copy, privacy (depends on A)

Owns:

- `config/routes.rb` (one scope, next to the coach block)
- `packs/job_applications/app/controllers/job_applications/{base_controller.rb,dashboard_controller.rb,preferences_controller.rb}`
- `packs/job_applications/app/views/job_applications/dashboard/{show.html.erb,_preferences.html.erb,_match_row.html.erb}`
- `app/views/shared/_site_header.html.erb` (two links, desktop ~line 22 and mobile ~line 75)
- `config/locales/seera_apply.en.yml`, `config/locales/seera_apply.ar.yml` (new), `nav.jobs` in `config/locales/en.yml` and `ar.yml`
- `app/views/pages/privacy/_body_en.html.erb`, `_body_ar.html.erb` (phrase edits only)
- `docs/state-machines.md` is A's; B does not edit it.
- Tests: `test/controllers/job_applications/dashboard_controller_test.rb`, `test/controllers/job_applications/preferences_controller_test.rb`

Details:

- Routes. `/jobs` is taken by SEO (`seo#cities_index`), so:
  ```ruby
  # Seera Apply (packs/job_applications), off unless SEERA_APPLY_ENABLED
  scope "my-jobs", module: :job_applications, as: :my_jobs do
    get "/", to: "dashboard#show", as: :root          # my_jobs_root_path
    patch "preferences", to: "preferences#update", as: :preferences
  end
  ```
- `BaseController`: branch version, `require_seera_apply!` raising `ActionController::RoutingError` (404 like coach).
- `DashboardController#show`: `@resume = ResumeBuilder::PublicApi.latest_complete(current_user)`,
  `@preference = preference`, `scope = Match.shown.where(user: current_user)`, `@count = scope.count`,
  `@matches = scope.includes(posting: :employer).order(score: :desc, "apply_postings.posted_at": :desc).limit(100)`.
- `PreferencesController#update`: permit `:titles` (string split on `,`, `،`, newline; squish, uniq,
  first 10) and `cities: []`; on save redirect to `my_jobs_root_path` with notice, and, when titles or
  cities changed and `!AiCircuit.busy?`, `MatchJob.perform_later(current_user.id)` so a tester sees
  results within minutes instead of tomorrow. Invalid → redirect with alert. No consent fields.
- View (`show.html.erb`), Seera glass like `packs/coach/app/views/coach/chats/index.html.erb`:
  `sr-page` wrapper with `dir="<%= text_direction %>"`, `max-w-[1040px]`, flash in `glass-soft`.
  1. No CV: one `glass rounded-[28px]` card, heading + `sr-btn sr-primary` link to `new_resume_path`. Nothing else.
  2. Preferences not ready: `_preferences` card first (titles text field, four city chips as
     checkbox labels styled `glass-soft rounded-full`, submit `sr-btn sr-primary`).
  3. Ready: hero card with the count in large type (`clamp(40px,6vw,64px)`) and `t("seera_apply.count")`
     beside it; then a list of `_match_row` cards (`glass sr-lift sr-up rounded-[28px]`): title (h2),
     company · city label, score badge `8/10`, whole card an `<a target="_blank" rel="noopener noreferrer">`
     to `posting.url`, icon `seera_icon("solar:case-bold")` / `solar:map-point-bold` (both exist in
     `config/icons/seera_icons.json`). Zero matches: the count shows 0, no extra text.
     Preferences sit in a `<details>` under the list, summary `t("seera_apply.edit")`.
  No taglines, subtitles or helper text.
- Copy (new files, root key `seera_apply`), en / ar:
  `title` "Jobs for you" / "وظائف لك"; `count` "jobs match you" / "وظيفة تناسبك" (the number is rendered
  separately, so no plural forms are needed; the app has no Arabic pluralizer);
  `no_cv` "Build your CV first" / "أنشئ سيرتك أولاً"; `build_cv` "Build my CV" / "أنشئ سيرتي";
  `titles` "Job titles" / "المسميات الوظيفية"; `cities.riyadh|jeddah|dammam|remote` "Riyadh/Jeddah/Dammam/Remote" /
  "الرياض/جدة/الدمام/عن بعد"; `save` "Save" / "حفظ"; `edit` "Edit preferences" / "تعديل التفضيلات";
  `score` "%{score}/10"; `flash.saved` "Saved" / "تم الحفظ"; `flash.invalid` "Check %{fields}" / "راجع %{fields}".
  `nav.jobs` "Jobs" / "الوظائف".
- Header: inside `if user_signed_in?`, right after each coach link, `if JobApplications.enabled_for?(current_user)` → `link_to t('nav.jobs'), my_jobs_root_path` with the same classes as the coach link in that spot.
- Privacy (en + ar, same places, no `PrivacyPolicy::VERSION` bump; bump it at public launch with the
  step-2 consent text). The Bedrock line (151) already says it receives your CV text, so only the purposes change:
  - line ~79 purposes: append "and matching your CV to job openings" / "ومطابقة سيرتك مع الوظائف المتاحة".
  - line ~151 Bedrock: "...translate your CV, match it to job openings and answer in the AI coach" / same in Arabic.
  - line ~52 AI results: add "job match scores" / "درجات مطابقة الوظائف".
  Do not port the branch's auto-apply privacy block.

Gate B: controller tests green; manual check in `bin/dev` with `SEERA_APPLY_TESTERS=<your dev email>`
in both locales (RTL layout, chips wrap at 375 px, link opens new tab); then the full CI list below.

## 4. Data

One migration, `db/migrate/20261127000100_create_seera_apply_tables.rb`, `ActiveRecord::Migration[8.1]`,
only `create_table`/`add_index` on new tables (safe under `StrongMigrations.start_after = 2026_11_09_000300`,
rolls back cleanly, no existing table touched). Then `bin/rails db:migrate` on the local dev DB to
regenerate `db/schema.rb`; never hand-merge the branch's schema.

| Table | Columns |
|---|---|
| `apply_employers` | `name` string null:false, `ats` string null:false, `identifier` string null:false, `host`, `site`, `country` string, `verified` bool null:false default false, `active` bool null:false default true, `last_fetched_at` datetime, `last_error` text, timestamps. Unique `[ats, identifier]`. |
| `apply_postings` | `employer` ref null:false FK `apply_employers` on_delete cascade, `external_id`, `title`, `url`, `apply_url` string null:false, `location`, `country`, `city` string, `description` text, `posted_at`, `fetched_at` null:false, `closed_at` datetime, timestamps. Unique `[employer_id, external_id]`; indexes `[city, closed_at]`, `posted_at`. |
| `apply_preferences` | `user` ref null:false unique index, FK users on_delete cascade; `titles` string array null:false default `[]`; `cities` string array null:false default `[]`; timestamps. |
| `apply_matches` | `user` ref null:false (no single index) FK users on_delete cascade; `posting` ref null:false FK `apply_postings` on_delete cascade; `score` integer null:false; `score_reason` text; timestamps. Unique `[user_id, posting_id]`; index `[user_id, score]`. |
| `apply_ai_usages` | `user` ref null:false (no single index) FK users on_delete cascade; `day` date null:false; `scores` integer null:false default 0; timestamps. Unique `[user_id, day]`. |

PDPL: account deletion already runs `user.destroy!` in `ProfilesController#destroy`; the three per-user
tables cascade on the users FK, like `coach_chats`, so `User` gets no new associations. Export adds the
`seera_apply` key through `JobApplications.export_for`. Postings and employers are public job data, not
personal data.

## 5. Tests

All under `test/`. `test/support/seera_apply_helper.rb` (ported from the branch's `auto_apply_helper.rb`,
minus `consent!`/`create_application`; plus `create_match`, `with_seera_apply_for(user)` setting
`SEERA_APPLY_TESTERS`). The branch tests `require` it explicitly: `test/support` is not auto-loaded.

Unit A:
- `test/services/job_applications/fetchers_test.rb`: per ATS, stub `http_get`/`http_post` on the fetcher
  instance (mocha) to return `ats_fixture(...)`; assert Gulf-only postings, fields, pagination for
  smartrecruiters/workable/workday (page1/page2 fixtures). No network.
- `test/services/job_applications/gulf_location_test.rb`: port as-is + `city_for` cases (Riyadh, جدة,
  "Al Khobar" → dammam, "Remote - Saudi Arabia" → remote, "Riyadh (Remote)" → riyadh, Dubai → nil).
- `test/services/job_applications/employer_seeder_test.rb`: loads `file_fixture("employers.yml")`, creates, updates, deactivates.
- `test/services/job_applications/matcher_test.rb`, `AiModel.stubs(:complete)` returning an object with
  `content` JSON: writes matches only for prefiltered titles and chosen cities; skips postings already
  matched; low scores stored but not in `Match.shown`; stops at `DAILY_SCORE_LIMIT` (`AiUsage` row);
  bad JSON writes nothing; `AiCircuit::OpenError` does not bump usage; no CV / no preference → 0 and no AI call
  (`AiModel.expects(:complete).never`); prompt contains no email or phone (`CvFacts`).
- `test/models/job_applications/preference_test.rb`: port, rewritten for `titles`/`cities` validation.
- `test/models/job_applications/match_test.rb`: uniqueness per user/posting; `shown` hides closed postings.
- `test/jobs/job_applications/fetch_postings_job_test.rb`: no-op when gate off; upserts and sets `city`;
  closes missing postings; one failing employer records `last_error` and others still fetch; enqueues `MatchJob`.
- `test/jobs/job_applications/match_job_test.rb`: skips users not enabled; single-user mode.
- User data export test: `seera_apply` key present with preference and matches; `user.destroy!` removes
  preference, matches and usage rows (FK cascade).

Unit B:
- `dashboard_controller_test.rb`: 404 when gate off (re-sign-in between requests, as coach tests do);
  signed-out → sign in; tester with no CV sees link to `new_resume_path` and no form; tester with CV and no
  preferences sees the form; with matches sees the count and one row per shown match with
  `a[href=posting.url][target=_blank]`; renders in `ar` locale; header shows `my_jobs_root_path` only for testers.
- `preferences_controller_test.rb`: saves titles/cities and enqueues `MatchJob` with the user id
  (`queue_adapter_for_test` TestAdapter, as coach tests do); invalid city rejected; 404 when gate off;
  no enqueue when `AiCircuit.busy?` is stubbed true.

## 6. docs/state-machines.md (Unit A adds this section after "Coach turn and send_to_seera")

```markdown
## Seera Apply fetch and match

No status column. `job_applications/app/jobs/job_applications/fetch_postings_job.rb`, daily 04:30
(`config/schedule.yml`), no-op unless `SEERA_APPLY_ENABLED` or `SEERA_APPLY_TESTERS`.

- Fetch: re-seeds `apply_employers` from `config/employers.yml`, then per employer upserts postings by
  `[employer_id, external_id]` and sets `closed_at` on ones the feed no longer lists. A failing feed
  writes `last_error` and never stops the run. Retention: closed > 90 days deleted (matches cascade),
  `apply_ai_usages` > 30 days deleted. Then enqueues `MatchJob`.
- Match: `MatchJob(user_id = nil)`; also enqueued by `PreferencesController#update` (skipped while
  `AiCircuit.busy?`). A posting is scored once per user (unique `[user_id, posting_id]`, `insert_all`).
  Budget: `DAILY_SCORE_LIMIT` (40) postings per user per day in `apply_ai_usages.scores`, bumped after each
  AI call; `AiCircuit::OpenError` bumps nothing and ends the run. No charge, so nothing to refund.
```

## 7. Risks and checks

- Route collision: `/jobs` is the SEO cities page; the plan uses `/my-jobs`. Check `bin/rails routes | grep my_jobs`
  and that `pages_controller_test`/SEO tests still pass.
- Header partial is on every page: a typo or missing icon breaks all pages. `seera_icon` raises on
  unknown names in dev/test; run the full suite, not just the pack's tests.
- Schedule: sidekiq-cron drops jobs missing from the file, so keep `data_retention`,
  `stale_work_sweeper`, `slo_check` exactly as they are.
- AI cost: the 40/day cap and the title prefilter bound it; the job is dark until the env is set.
  A test asserts no AI call without CV/preferences.
- Long fetch: 74 feeds × up to 10 pages with 20 s timeouts runs in one Sidekiq job; upserts make a
  killed run safe to repeat. If it proves slow, step 2 can fan out per employer.
- Packwerk: `bin/packwerk check` must stay clean (only `PublicApi` into resume_builder). Do not add
  to `package_todo.yml`.
- strong_migrations: new tables only; a migration that alters an existing table would fail here.
- Privacy: edits are phrase additions only; diff both locale bodies and keep the Arabic and English in step.
- Do not touch `config/deploy.yml`, `packs/accounts/app/views/profiles/show.html.erb`, production data or secrets.

## Acceptance gates (run in this order, all must pass)

```bash
bin/rails db:migrate && bin/rails db:rollback && bin/rails db:migrate   # local dev DB only
bin/packwerk validate && bin/packwerk check
bin/rubocop
bin/brakeman --no-pager
bin/importmap audit
bin/rails db:test:prepare test test:system
```

Done when: all gates pass; with the env unset nobody sees the link and `/my-jobs` is 404; with
`SEERA_APPLY_TESTERS` set to a dev user, the page shows the three states in English and Arabic; and
`git diff --stat main` lists no file outside the ownership lists above.
