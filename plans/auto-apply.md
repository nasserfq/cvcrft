# Auto-apply: jobs from employer ATS feeds, applied for from the user's browser

Owner: Nasser. Pack: `packs/job_applications` (new). Extension: `extension/` (new).
Feature flag: `AUTO_APPLY_ENABLED` / `AUTO_APPLY_TESTERS`, so it is off by default.

## 1. Goal

When the flag is on for a user:

- A header link "Auto-apply" / "التقديم التلقائي" opens `/auto_apply`, a Seera glass page with four cards:
  1. **Preferences**: target titles, countries, minimum match score (1-10, default 7), daily cap (default 10, max 25), mode (review / auto), optional LinkedIn URL, and a consent checkbox with the bilingual consent text. Nothing is matched until consent is saved.
  2. **Extension**: "Connect extension" creates a pairing token and shows it once. After that the card shows the token's last use and a "Revoke" button.
  3. **Queue** (review mode): matched jobs with their score and reason, and Approve / Skip buttons.
  4. **Tracker**: every application with its status, company, title, date, a link to the posting and a Delete button.
- Every day, postings are fetched from the public ATS feeds of the employers in `packs/job_applications/config/employers.yml`. Only Saudi/Gulf postings are kept. Each consenting user with a finished CV gets matches scored 1-10 by AI.
- The Chrome extension (paired with the token) picks the next approved application. It opens the company's own apply page, fills it from the CV, uploads the PDF, answers the extra questions with AI (from CV facts only), submits it (unless dry-run is on), and reports the result. CAPTCHAs, login walls and required questions it cannot answer become `needs_user`, and the tab stays open for the user.
- Profile "Download my data" includes the new tables. Account deletion removes them.

## 2. Approach

**Fetch on the server, apply in the browser.** The server only reads public, unauthenticated job-board JSON feeds, which ATS vendors publish for this purpose. The actual application happens in the user's own browser session on the employer's page, run by an extension the user installed and controls. The obvious alternative is to submit applications from the server through ATS "apply" APIs. That needs per-employer API keys (Greenhouse and Lever apply APIs are employer-keyed), breaks the sites' terms, and would make Seera the submitter of record. Doing it in the browser keeps the user as the applicant. They can watch, stop or take over any tab, and Seera never holds a third-party password.

**One pack, small public surfaces.** All server code lives in `packs/job_applications` under the module `JobApplications`, with tables prefixed `auto_apply_`. It reaches resumes only through `ResumeBuilder::PublicApi`, which gets two new methods, `latest_complete` and `pdf`. AI goes through `AiModel.complete` / `AiModel.json_body` (root initializer). Fetchers use `Net::HTTP`, because Faraday is only a transitive dependency of ruby_llm and is not in the Gemfile. That matches `Billing::MoyasarClient`.

**Token API for the extension.** `/api/extension/v1/*` inherits `ActionController::API`, so there is no `allow_browser`, CSRF, session or Devise. It authenticates with `X-Seera-Token` (not `Authorization`, which `test/test_helper.rb` overwrites with Basic auth). Tokens are stored only as a SHA256 digest. Requests come from the extension's service worker, which has `host_permissions` for the Seera origin, so Chrome skips CORS. No CORS middleware is added. The extension never sends a `Cookie`, and the API ignores sessions.

## 3. Work units

Two units that can be built at the same time. No file is owned by both. Unit B builds against the contract in section 3.3 and can test with a stub server or the real dev server once A lands.

### 3.1 Unit A: Rails (`software-engineer` #1)

Owns: `packs/job_applications/**`, `db/migrate/2026102000010*_*.rb`, `db/schema.rb`, `config/routes.rb`, `config/schedule.yml`, `config/locales/auto_apply.en.yml`, `config/locales/auto_apply.ar.yml`, `app/views/shared/_site_header.html.erb`, `config/locales/en.yml` + `ar.yml` (only the new `nav.auto_apply` key), `packs/resume_builder/app/public/resume_builder/public_api.rb`, `packs/accounts/app/models/user.rb` (associations only), `packs/accounts/app/services/user_data_export.rb`, `packs/accounts/app/views/profiles/show.html.erb` (one link card), `test/**`.

Does not touch `packs/job_applications/config/employers.yml`. Another agent writes it. Unit A reads it, and adds a fixture copy under `test/fixtures/files/employers.yml` for tests.

#### A1. Pack skeleton

- `packs/job_applications/package.yml`:
  ```yaml
  enforce_dependencies: true
  enforce_privacy: false
  dependencies:
    - "."
    - packs/accounts
    - packs/resume_builder
  ```
- `packs/job_applications/app/services/job_applications.rb`:
  ```ruby
  module JobApplications
    def self.enabled_for?(user)  # same as Coach.enabled_for?, with AUTO_APPLY_ENABLED / AUTO_APPLY_TESTERS
    def self.table_name_prefix = "auto_apply_"
    CONSENT_VERSION = "2026-10-20"
    DAILY_CAP_MAX = 25
    DAILY_SCORE_LIMIT = 40      # AI scoring calls per user per day
    DAILY_ANSWER_LIMIT = 60     # answers + cover-letter calls per user per day
  end
  ```
- Add `packs/job_applications` to the README pack table (`packs/README.md`): "Job feeds, matching, auto-apply queue and extension API. Off unless `AUTO_APPLY_ENABLED`".

#### A2. Migrations (`db/migrate/20261020000100_create_auto_apply_tables.rb`)

All new tables. Nothing existing is changed, so the migration is backwards compatible and reversible with `change`.

| table | columns |
|---|---|
| `auto_apply_employers` | `name` string not null, `ats` string not null, `identifier` string not null, `host` string, `site` string, `country` string, `verified` boolean default false not null, `active` boolean default true not null, `last_fetched_at` datetime, `last_error` text, timestamps. Unique index `[ats, identifier]`. |
| `auto_apply_postings` | `employer_id` FK (on_delete cascade) not null, `external_id` string not null, `title` string not null, `location` string, `country` string, `url` string not null, `apply_url` string not null, `description` text, `posted_at` datetime, `fetched_at` datetime not null, `closed_at` datetime, timestamps. Unique `[employer_id, external_id]`, index `posted_at`, index `closed_at`. |
| `auto_apply_preferences` | `user_id` FK (on_delete cascade) not null **unique**, `titles` string[] default [] not null, `countries` string[] default ["SA"] not null, `min_score` integer default 7 not null, `daily_cap` integer default 10 not null, `mode` string default "review" not null, `linkedin_url` string, `consent_accepted_at` datetime, `consent_version` string, `paused` boolean default false not null, timestamps. |
| `auto_apply_applications` | `user_id` FK cascade not null, `posting_id` FK cascade not null, `resume_id` bigint (no FK, so resume deletion never blocks), `status` string not null default "queued", `score` integer, `score_reason` text, `cover_letter` text, `error` text, `details` jsonb default {} not null, `started_at`, `submitted_at`, `finished_at` datetime, timestamps. Unique `[user_id, posting_id]`; index `[user_id, status, created_at]`. |
| `auto_apply_tokens` | `user_id` FK cascade not null, `token_digest` string not null unique, `last_used_at` datetime, `revoked_at` datetime, timestamps. |
| `auto_apply_ai_usages` | `user_id` FK cascade not null, `day` date not null, `scores` integer default 0 not null, `answers` integer default 0 not null, timestamps. Unique `[user_id, day]`. Counts AI calls per user per day (`answers` also counts cover letters). Rows older than 30 days are deleted by `FetchPostingsJob`. |

Statuses: `queued` (review mode, waiting for the user), `approved`, `in_progress`, `submitted`, `failed`, `needs_user`, `skipped`. The CHECK constraint stays in the model (`validates :status, inclusion:`).

#### A3. Models (`packs/job_applications/app/models/job_applications/`)

`employer.rb`, `posting.rb` (`scope :open`, `scope :fresh, -> { where(fetched_at: 2.days.ago..) }`), `preference.rb` (validations: `min_score` 1..10, `daily_cap` 1..25, `mode` in review/auto, `consent_accepted?` = `consent_version == CONSENT_VERSION`), `application.rb` (`belongs_to :posting`, statuses, `scope :submitted_today`, `def self.next_for(user)`), `token.rb`, `ai_usage.rb` (table `auto_apply_ai_usages`; `AiUsage.for(user, day)` find-or-create, `AiUsage.bump!(user, :scores, n = 1)` via `upsert_all` + `update_counters`).

`Token`:
```ruby
def self.issue!(user)  # revokes the user's existing tokens, returns [token, raw]
  raw = "seera_" + SecureRandom.urlsafe_base64(32)
  [create!(user:, token_digest: digest(raw)), raw]
end
def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw.to_s)
def self.authenticate(raw) = where(revoked_at: nil).find_by(token_digest: digest(raw))
```
One active token per user (issuing a new one revokes the old one).

User associations (in `packs/accounts/app/models/user.rb`, for export and `dependent:`): `has_one :auto_apply_preference, class_name: "JobApplications::Preference", dependent: :delete`, `has_many :auto_apply_applications, class_name: "JobApplications::Application", dependent: :delete_all`, `has_many :auto_apply_tokens, class_name: "JobApplications::Token", dependent: :delete_all`. The FKs also cascade, so this works either way, the same way coach_chats are handled. If packwerk flags it, add it to `packs/accounts/package_todo.yml` (accounts has `enforce_dependencies: false`, so it should not).

#### A4. Employer seeding

- `packs/job_applications/app/services/job_applications/employer_seeder.rb`: `EmployerSeeder.call(path = Rails.root.join("packs/job_applications/config/employers.yml"))`. It loads the YAML with `YAML.safe_load_file`, validates `ats` against `Fetchers::REGISTRY.keys`, and upserts on `[ats, identifier]`. It marks rows missing from the file `active: false` and never deletes them, so their postings and applications stay. Returns `{created:, updated:, deactivated:, invalid: [...]}`.
- `lib/tasks/job_applications.rake` (root, next to `resumes.rake`, because Rails only loads rake files from `lib/tasks`): `job_applications:seed_employers` and `job_applications:fetch` (runs `FetchPostingsJob.perform_now`). Unit A owns it.

#### A5. Fetchers (`packs/job_applications/app/services/job_applications/fetchers/`)

`base.rb`:
```ruby
class Base
  Posting = Struct.new(:external_id, :title, :location, :country, :url, :apply_url, :description, :posted_at, keyword_init: true)
  def initialize(employer) ; end
  def call -> Array<Posting>          # all pages, only Gulf (via GulfLocation)
  private
  def http_get(url) -> Hash           # Net::HTTP, open 5s / read 20s, JSON.parse, raise FetchError on non-2xx
  def http_post(url, body) -> Hash
  def html_to_text(html)              # Nokogiri (in Gemfile via rails) -> squished text, max 20_000 chars
end
REGISTRY = { "greenhouse" => Greenhouse, "lever" => Lever, "ashby" => Ashby,
             "workable" => Workable, "smartrecruiters" => SmartRecruiters, "workday" => Workday }
```
Each fetcher overrides `call` and only uses `http_get` / `http_post`, so tests stub those with mocha (no webmock in the Gemfile).

| class | request | mapping notes |
|---|---|---|
| `Greenhouse` | GET `https://boards-api.greenhouse.io/v1/boards/{identifier}/jobs?content=true` | `jobs[]`: id, title, `location.name`, `absolute_url` (url = apply_url), `content` is HTML-escaped, so `CGI.unescapeHTML` then `html_to_text`, `updated_at`. |
| `Lever` | GET `https://api.lever.co/v0/postings/{site||identifier}?mode=json` | array: id, text, `categories.location` / `country`, `hostedUrl`, `applyUrl`, `descriptionPlain`, `createdAt` (ms). |
| `Ashby` | GET `https://api.ashbyhq.com/posting-api/job-board/{identifier}?includeCompensation=false` | `jobs[]`: id, title, location, `address.postalAddress.addressCountry`, `jobUrl`, `applyUrl`, `descriptionPlain`, `publishedAt`. Skip `isListed == false`. |
| `Workable` | POST `https://apply.workable.com/api/v3/accounts/{identifier}/jobs` body `{"query":"","location":[],"department":[],"worktype":[],"remote":[]}` then follow `nextPage` token (max 10 pages) | `results[]`: shortcode, title, `location.city`/`country`, url = `https://apply.workable.com/{id}/j/{shortcode}/`, apply_url = url + `apply/`, `published`. Description: none in the list, so leave it blank (the matcher uses the title only). |
| `SmartRecruiters` | GET `https://api.smartrecruiters.com/v1/companies/{identifier}/postings?limit=100&offset=N` until `offset >= totalFound` (max 10 pages) | `content[]`: id, name, `location.city`/`country`, url = `https://jobs.smartrecruiters.com/{identifier}/{id}`, apply_url same, `releasedDate`. |
| `Workday` | POST `https://{host}/wday/cxs/{identifier}/{site}/jobs` body `{"limit":20,"offset":N,"searchText":""}` until offset >= `total` (max 10 pages, i.e. 200 jobs) | `jobPostings[]`: `externalPath`, title, `locationsText`, url = apply_url = `https://{host}/en-US/{site}{externalPath}`, external_id = `bulletFields.first || externalPath`, `postedOn` is text ("Posted 3 Days Ago"), so parse it roughly or leave it nil. |

`gulf_location.rb`: `GulfLocation.country_for(*strings) -> "SA"|"AE"|"QA"|"KW"|"BH"|"OM"|nil`. It matches keyword tables, case-insensitively, after Arabic normalisation (أ/إ/آ→ا, ة→ه, strip tatweel):
- SA: saudi, ksa, riyadh, jeddah, dammam, khobar, dhahran, mecca, makkah, medina, madinah, tabuk, abha, jubail, yanbu, neom, qassim, buraidah, taif, hail, "السعودية", "الرياض", "جدة", "الدمام", "الخبر", "الظهران", "مكة", "المدينة", "تبوك", "أبها", "الجبيل", "ينبع", "نيوم", "القصيم", "الطائف", "حائل".
- AE: uae, united arab emirates, dubai, abu dhabi, sharjah, ajman, "الإمارات", "دبي", "أبوظبي", "الشارقة". QA: qatar, doha, "قطر", "الدوحة". KW: kuwait, "الكويت". BH: bahrain, manama, "البحرين", "المنامة". OM: oman, muscat, "عمان", "مسقط".
- ISO codes from the feeds (`SA`, `SAU`, ...) map directly. Use word boundaries for Latin text, so "Omaha" never matches "oman".
- A posting is kept when `country_for(location, country_field, employer.country)` is set. The employer country is only a fallback when the location is empty or "Remote".

#### A6. Jobs (`packs/job_applications/app/jobs/job_applications/`)

- `FetchPostingsJob` (queue `default`): for each `Employer.where(active: true)`, it calls `REGISTRY[ats].new(e).call` and upserts postings on `[employer_id, external_id]` (`fetched_at: now`, `closed_at: nil`). Postings of that employer not seen in this run get `closed_at = now`. On error it stores `last_error`, reports to Sentry (`Sentry.capture_exception`), and continues with the next employer. Then it enqueues `MatchJob.perform_later`.
- `MatchJob`: for each preference with `consent_accepted?`, `paused: false`, `titles.any?`, and `ResumeBuilder::PublicApi.latest_complete(user)` present, it calls `Matcher.new(user).call`.
- `config/schedule.yml` entry:
  ```yaml
  auto_apply_fetch:
    cron: "30 4 * * *"
    class: "JobApplications::FetchPostingsJob"
    queue: default
  ```
  The job checks nothing about the flag itself. Fetching public feeds is harmless, and matching only runs for consenting users. To keep it fully dark in production until launch, `FetchPostingsJob#perform` returns early unless `ENV["AUTO_APPLY_ENABLED"] == "true" || ENV["AUTO_APPLY_TESTERS"].present?`.
- Retention: `DataRetentionJob` is owned by accounts and is not edited. Instead `FetchPostingsJob` ends with `Posting.where(closed_at: ...90.days.ago).where.missing(:applications).delete_all`, and `Application.where(status: %w[queued skipped], created_at: ...60.days.ago).delete_all`.

#### A7. Matching (`packs/job_applications/app/services/job_applications/matcher.rb`)

1. Candidates: `Posting.open.fresh.where(country: prefs.countries)`, excluding postings that already have an application for the user. The keyword prefilter keeps a posting when any normalised title token set from `prefs.titles` overlaps the posting title (lowercase, Arabic-normalised, stop words like "senior/junior/sr/lead" removed, at least 1 shared token of 3+ chars). Order by `posted_at desc`, limit 50.
2. Budget: `remaining = DAILY_SCORE_LIMIT - AiUsage.for(user, today).scores`. Score at most `remaining` postings, 5 per AI call (batched prompt).
3. Prompt (`system`): "You rate how well a candidate fits a job, 1-10. Use only the CV facts given. Reply JSON `{"scores":[{"posting_id":int,"score":int,"reason":"one sentence"}]}`." `user`: CV facts (`PublicApi.read`, sliced to titles/companies/skills/education/summary, max 6k chars) + postings (id, title, location, first 1,500 chars of the description). Parse with `JSON.parse(AiModel.json_body(msg.content))`, clamp scores to 1..10, and ignore unknown ids. On a parse error or AI error, log it and skip the batch (no application is created).
4. For each score >= `min_score`, create `Application(status: prefs.mode == "auto" ? "approved" : "queued", score:, score_reason:, resume_id:)`. Below the threshold: create it with status `skipped` and `details: {"reason":"below_min_score"}`, so the posting is never scored again.

#### A8. `ResumeBuilder::PublicApi` additions (`packs/resume_builder/app/public/resume_builder/public_api.rb`)

```ruby
# Newest finished (non-draft) resume, as {"id"=>..., "title"=>..., "updated_at"=>...}, or nil.
def latest_complete(user)
# {filename: "Name_CV.pdf", data: "<binary>"} for one of the user's non-draft resumes.
# ResumePdfService.generate_pdf may return bytes or {path:}; both handled (File.binread).
def pdf(user, resume_id)
```
Test: `test/services/resume_builder/public_api_test.rb` (add cases).

#### A9. Cover letter and answers (`packs/job_applications/app/services/job_applications/`)

- `CoverLetter.for(application)`: returns `application.cover_letter` if present. Otherwise it makes one AI call (temperature 0.4, max_tokens 700): 150-250 words, English unless the posting is Arabic (detect with `contains_arabic?` logic). It uses only CV facts and must not invent employers, degrees or numbers. It stores and returns the text, and counts toward `AiUsage.answers`.
- `Answerer.new(application).call(questions)`. Input is validated: at most 40 questions, label ≤ 300 chars, options ≤ 50 each. Prompt rules: answer only from CV facts and preferences (name, email, phone, city, country, LinkedIn). Return `null` when the CV does not say. Never invent. For `select`/`radio`/`checkbox` types the value must be exactly one of `options` (checkbox: an array of options). Yes/no consent or legal questions (visa sponsorship, criminal record, disability, gender, salary expectations) are always `null`. Post-processing enforces the options rule in Ruby: a value not in `options` becomes `null`. Unknown ids are dropped. A missing id gets `null`.

#### A10. Web UI (`packs/job_applications/app/controllers/job_applications/`, `app/views/job_applications/`)

Routes (`config/routes.rb`, after the coach block):
```ruby
# Auto-apply (packs/job_applications), off unless AUTO_APPLY_ENABLED
scope :auto_apply, module: :job_applications, as: :auto_apply do
  get "/", to: "dashboard#show", as: :root
  patch "preferences", to: "preferences#update", as: :preferences
  post "token", to: "tokens#create", as: :token
  delete "token", to: "tokens#destroy"
  resources :applications, only: [:destroy] do
    member { post :approve; post :skip }
  end
end

namespace :api do
  namespace :extension do
    namespace :v1 do
      get "me", to: "me#show"
      get "profile", to: "profiles#show"
      get "resume.pdf", to: "resumes#show", as: :resume_pdf, format: false
      get "applications/next", to: "applications#next"
      post "applications/:id/answers", to: "applications#answers"
      patch "applications/:id", to: "applications#update"
    end
  end
end
```
`config/routes.rb` already has `namespace :api do` (line ~182, translations). Put the `namespace :extension { namespace :v1 { ... } }` block **inside that existing block** and do not open a second `namespace :api`. Controllers go in `packs/job_applications/app/controllers/api/extension/v1/` (module `Api::Extension::V1`). That is fine with Zeitwerk because `Api` is already an implicit namespace from `packs/accounts/app/controllers/api`.

Controllers (`< ApplicationController`, `before_action :authenticate_user!, :require_auto_apply!`, where `require_auto_apply!` raises `ActionController::RoutingError, "Not Found"` unless `JobApplications.enabled_for?(current_user)`):
- `DashboardController#show`: `@preference` (find or new), `@token` (active), `@queue` (status queued, by score desc, includes posting+employer), `@applications` (all other statuses, newest first, paginated to 100), `@resume` (`latest_complete`), `@daily_remaining`.
- `PreferencesController#update`: permits `titles` (comma or newline separated text → array, max 10, each ≤ 80), `countries` (subset of `%w[SA AE QA KW BH OM]`), `min_score`, `daily_cap`, `mode`, `linkedin_url` (must be https and linkedin.com), `consent` ("1"). When consent is ticked, it sets `consent_accepted_at = now, consent_version = CONSENT_VERSION`. When it is unticked, it clears both. Redirects with a notice.
- `TokensController#create`: `Token.issue!`, then `flash[:auto_apply_token] = raw` and a redirect. The dashboard shows it once in a copy box ("You will not see this again"). `#destroy` sets `revoked_at` on all of the user's tokens.
- `ApplicationsController#approve` (queued → approved), `#skip` (queued/approved/needs_user → skipped), `#destroy` (the user's own row, any status). Turbo-stream replace of the row, with HTML redirect as the fallback.

Views (copy the structure of `packs/coach/app/views/coach/chats/index.html.erb` and `packs/accounts/app/views/profiles/show.html.erb`: `.glass` cards, `.sr-btn .sr-primary` buttons, `dir` from `text_direction`): `show.html.erb`, `_preferences.html.erb`, `_extension.html.erb`, `_queue.html.erb`, `_tracker.html.erb`, `_application_row.html.erb`. Status badges use the existing glass badge classes. Without a finished CV, show a card linking to `resumes_path`.

Header: `app/views/shared/_site_header.html.erb`, desktop and mobile, next to the coach link, `if JobApplications.enabled_for?(current_user)`, `t('nav.auto_apply')`. Profile page: one small glass card "Auto-apply" linking to `auto_apply_root_path`, only when the flag is on.

Locales: new files `config/locales/auto_apply.en.yml` and `auto_apply.ar.yml`, top key `auto_apply:` (Rails loads `config/locales/*.yml` already, the same way as the `pdpl_*` files). `nav.auto_apply` goes into `en.yml` / `ar.yml`. Consent text (`auto_apply.consent.body`), English:
> By turning on auto-apply you agree that: (1) Seera sends your CV and the details in it to the employer for each application; (2) applications are filled in and submitted by an automated tool running in your own browser; (3) you are responsible for the answers submitted on your behalf, so review them; (4) some job sites forbid automated use, and applying through them may break their terms. You can pause, revoke the extension or delete your applications at any time.

Arabic is the equivalent in Arabic, with all four points. Every label, status name (`auto_apply.status.submitted` …), flash and empty state has en + ar. Add a test (`test/i18n/auto_apply_locales_test.rb`) that the en and ar `auto_apply` key trees are identical.

#### A11. Extension API (`packs/job_applications/app/controllers/api/extension/v1/`)

`base_controller.rb`:
```ruby
module Api::Extension::V1
  class BaseController < ActionController::API
    include ActionController::RateLimiting   # if not already in API in this Rails version
    before_action :authenticate_token!
    rate_limit to: 120, within: 1.minute, by: -> { request.headers["X-Seera-Token"].to_s[0, 16] }, with: -> { render json: { error: "rate_limited" }, status: :too_many_requests }
    around_action :use_user_locale
    private
    def authenticate_token!
      @token = JobApplications::Token.authenticate(request.headers["X-Seera-Token"])
      return render(json: { error: "unauthorized" }, status: :unauthorized) unless @token
      return render(json: { error: "disabled" }, status: :forbidden) unless JobApplications.enabled_for?(@token.user)
      @token.update_column(:last_used_at, Time.current) if @token.last_used_at.nil? || @token.last_used_at < 1.minute.ago
    end
    def current_user = @token.user
  end
end
```
Note: the feature flag on the API returns `403 {"error":"disabled"}` and not a RoutingError, so the extension can show a clear message. The web UI still raises RoutingError. Per-endpoint extra limits: `answers` 30/min, `next` 20/min. The test env uses `:null_store`, so rate-limit tests set `rate_limit store: ActiveSupport::Cache::MemoryStore.new` through a class constant `RATE_STORE` that tests can swap. Otherwise they skip the 429 assertion.

### 3.2 Unit B: Chrome extension (`software-engineer` #2)

Owns only `extension/**`. It touches nothing in the Rails app.

```
extension/
  manifest.json
  package.json                 # {"name":"seera-auto-apply","private":true,"type":"module","scripts":{"test":"node --test test/"}}
  README.md                    # install (chrome://extensions → Developer mode → Load unpacked → extension/), pairing, dry-run, privacy, limits
  src/config.js                # DEFAULT_ORIGIN = "https://cvcrft.com", DEV_ORIGIN = "http://localhost:3000"
  src/api.js                   # fetch wrapper: base origin from storage, X-Seera-Token header, JSON errors → ApiError(status, code)
  src/background.js            # service worker (type: module)
  src/popup.html, popup.css, popup.js
  src/content/runner.js        # injected entry: picks adapter by location.host, runs it, posts result
  src/content/fill.js          # fill helpers (DOM)
  src/adapters/greenhouse.js, lever.js, ashby.js, workable.js, smartrecruiters.js, workday.js, generic.js
  src/lib/labels.js            # PURE: normalise(label), matchStandardField(label, attrs) -> "first_name"|"last_name"|"full_name"|"email"|"phone"|"city"|"country"|"location"|"linkedin"|"resume"|"cover_letter"|null
  src/lib/captcha.js           # PURE: detectCaptcha({iframeSrcs, scriptSrcs, classNames}) -> "recaptcha"|"hcaptcha"|"turnstile"|null; detectLoginWall({url, hasPasswordInput, text}) -> bool
  src/lib/delay.js             # PURE: nextDelayMs(rand=Math.random) -> 60_000..180_000
  src/lib/questions.js         # PURE: toQuestion(fieldDescriptor) -> {id,label,type,options,required}; applyAnswer plan
  icons/16.png 48.png 128.png  # simple glyph, green on dark (#0b1210)
  test/labels.test.js, captcha.test.js, delay.test.js, questions.test.js
```

`manifest.json`:
```json
{
  "manifest_version": 3,
  "name": "Seera Auto-apply",
  "version": "0.1.0",
  "description": "Applies to jobs you approved in Seera, on the employer's own page.",
  "permissions": ["storage", "tabs", "scripting", "alarms"],
  "host_permissions": [
    "https://cvcrft.com/*", "http://localhost:3000/*",
    "https://boards.greenhouse.io/*", "https://job-boards.greenhouse.io/*",
    "https://jobs.lever.co/*", "https://jobs.ashbyhq.com/*",
    "https://apply.workable.com/*", "https://jobs.smartrecruiters.com/*",
    "https://*.myworkdayjobs.com/*"
  ],
  "background": { "service_worker": "src/background.js", "type": "module" },
  "action": { "default_popup": "src/popup.html" },
  "icons": { "16": "icons/16.png", "48": "icons/48.png", "128": "icons/128.png" }
}
```
A custom Seera origin, set in the popup's "Server" field under Advanced, must be one of the two listed origins. Otherwise the README says to add it to `host_permissions` and reload. No `optional_host_permissions` in v0.1.

Popup (dark Seera glass look: background `#0b1210`, translucent card, green primary button, and strings in en + ar picked from `navigator.language`, held in a small `src/i18n.js` dictionary): a token field (Save → `GET me` to verify, then shows the name/email), Start / Pause, "Today: N submitted, M remaining", a dry-run toggle (default **on** for first install), and the last 5 results with links.

Service worker loop:
1. `chrome.alarms.create("tick", { delayInMinutes: 0.1 })` on Start. Running state lives in `chrome.storage.local` (`{running, dryRun, origin, token, currentApplicationId, currentTabId}`). Service workers sleep, so all state is in storage, never in globals.
2. On `tick`: if not running, stop. If `currentApplicationId` is set, wait (a timeout of 10 min turns it into `PATCH failed {error:"timeout"}`). Otherwise `GET applications/next`. On `204`, schedule the next tick in 30 min. On `429 daily_cap_reached`, pause until local midnight and show it in the popup.
3. Open `apply_url` with `chrome.tabs.create({active: false})`, wait for `status: complete`, then `chrome.scripting.executeScript({files: ["src/content/runner.js"]})` and send the job payload with `chrome.tabs.sendMessage` (application, profile, resume as base64 fetched once per run from `GET resume.pdf`, `dryRun`).
4. The runner replies `{status, error, details}`. The worker sends `PATCH applications/:id`. On `needs_user`, it makes the tab active, sets the action badge text to "!" (no `notifications` permission is needed), and never closes the tab. On `submitted`/`failed`/`skipped`, it closes the tab after 5 s.
5. The next tick comes after `nextDelayMs()` (1-3 min, uniform random). There are no fingerprint, user-agent, timing-evasion or CAPTCHA-solving tricks.

Adapter contract (each `src/adapters/*.js` exports the same shape, and runner.js imports them through a static map. Content scripts injected with `files` cannot use ES `import`, so the adapters are written as plain scripts that register on `globalThis.SeeraAdapters`, and `executeScript({files: [lib files..., adapters..., runner.js]})`):
```js
SeeraAdapters.greenhouse = {
  matches: (url) => /(^|\.)greenhouse\.io$/.test(url.hostname),
  async run(ctx) /* ctx: {application, profile, resumeFile: File, coverLetter, dryRun, api: {answers(questions)}} */
    // -> {status: "submitted"|"needs_user"|"failed", error?: string, details?: {filled:[], unanswered:[], captcha?:string}}
};
```
Steps every adapter follows (shared in `fill.js`):
1. `detectCaptcha` and `detectLoginWall` before filling. If either is found → `needs_user` (`details.captcha` or `details.login_wall: true`). Workday: if the page shows "Sign In" / "Create Account" / a password input → `needs_user` with `error: "account_required"`.
2. Click the site's "Apply" button if the form is not yet on the page (Lever `/apply`, Ashby "Application" tab, Workable `apply/`, SmartRecruiters "I'm interested").
3. Fill the standard fields via `matchStandardField` (`label` text, `name`, `id`, `autocomplete`, `aria-label`). Set values with the native setter + `input`/`change` events, so React forms register them.
4. Resume: `new DataTransfer()`, `dt.items.add(resumeFile)`, `input.files = dt.files`, then dispatch `change`. Cover letter goes into a textarea, or into a file input labelled "cover letter" as a generated `.txt` File.
5. Collect the remaining visible, empty inputs into questions (`toQuestion`). The id is a stable selector key the adapter can resolve later (`data-seera-q="n"` stamped on the element). Then call `api.answers(questions)` and fill non-null answers. Selects and radios only take option text that matches exactly.
6. If any `required` question is still empty → `needs_user` with `details.unanswered: [labels]`.
7. If `dryRun` → `{status: "needs_user", details: {dry_run: true}}`, leaving the tab open and filled. Otherwise click submit. Then wait up to 20 s for a confirmation signal (URL change to `/confirmation`/`thank`, or text such as "Thank you for applying", "Application submitted", "شكراً"). Found → `submitted`. Validation errors on the page → `needs_user`. Anything else → `failed` with `error: "no_confirmation"`.

`generic.js` handles any other host with the same steps and no apply-button click.

### 3.3 HTTP contract (A builds it, B consumes it)

Base: `{origin}/api/extension/v1`. Every request sends `X-Seera-Token: <raw token>` and `Accept: application/json`. JSON bodies send `Content-Type: application/json`. Errors are always `{"error": "<code>", "message": "<localised text>"}`.

| status | error code | meaning for the extension |
|---|---|---|
| 401 | `unauthorized` | token missing/revoked; clear it, stop, ask to re-pair |
| 403 | `disabled` | feature off for this user; stop |
| 403 | `consent_required` | prefs not consented; stop, link to `/auto_apply` |
| 404 | `not_found` | application not the user's / no finished CV |
| 409 | `invalid_transition` | PATCH from a state that does not allow it |
| 422 | `invalid` | bad body; `message` explains |
| 429 | `rate_limited` / `daily_cap_reached` / `ai_limit_reached` | back off 5 min (rate) / pause until local midnight (cap) / mark current one `needs_user` (AI limit) |

**GET `/me`** → 200
```json
{ "user": {"name":"Nasser","email":"n@example.com","locale":"ar"},
  "preferences": {"titles":["Product Manager"],"countries":["SA"],"min_score":7,"daily_cap":10,"mode":"review","consent":true,"paused":false},
  "today": {"submitted":3,"remaining":7,"in_progress":0},
  "has_resume": true }
```

**GET `/profile`** → 200 (404 `not_found` without a finished CV). Built from `PublicApi.read(user, latest_complete.id)` + preference:
```json
{ "resume_id": 12,
  "first_name": "Nasser", "last_name": "Alfaqih", "full_name": "Nasser Alfaqih",
  "email": "n@example.com", "phone": "+9665...", "city": "Riyadh", "country": "Saudi Arabia",
  "linkedin_url": "https://www.linkedin.com/in/...",
  "summary": "...",
  "work_experience": [{"job_title":"","company":"","start_date":"2021-01-01","end_date":null,"is_current":true}],
  "education": [{"degree":"","institution":"","start_date":"","end_date":""}],
  "skills": ["Ruby","SQL"], "languages": [{"language":"Arabic","proficiency":"Native"}] }
```
Name split: the first token is the first name, the rest the last name.

**GET `/resume.pdf`** → 200 `application/pdf`, `Content-Disposition: attachment; filename="Nasser_CV.pdf"`. The extension builds `new File([blob], filename, {type: "application/pdf"})`.

**GET `/applications/next`** → 200, or 204 (no body) when nothing is approved. 429 `daily_cap_reached` when `submitted today >= daily_cap`. 403 `consent_required`. In one transaction, with `lock("FOR UPDATE SKIP LOCKED")`: it takes the oldest `approved` application, sets `status: "in_progress", started_at: now`, and generates the cover letter if missing (`CoverLetter.for`). If AI fails, `cover_letter` is `null` and it does not error. Applications stuck `in_progress` for over 30 min are returned to `approved` first (so a crashed browser does not lose them).
```json
{ "application": {
    "id": 345, "status": "in_progress", "score": 8, "score_reason": "...",
    "apply_url": "https://job-boards.greenhouse.io/acme/jobs/123", "ats": "greenhouse",
    "cover_letter": "Dear hiring team, ...",
    "posting": {"title":"Product Manager","company":"Acme","location":"Riyadh, Saudi Arabia","country":"SA","url":"https://...","posted_at":"2026-10-18T00:00:00Z"} } }
```

**POST `/applications/:id/answers`** (only while `in_progress`, else 409). Request:
```json
{ "questions": [
  {"id":"q1","label":"Years of experience with SQL","type":"text","options":[],"required":true},
  {"id":"q2","label":"Are you legally authorised to work in Saudi Arabia?","type":"select","options":["Yes","No"],"required":true},
  {"id":"q3","label":"Languages","type":"checkbox","options":["Arabic","English","French"],"required":false} ] }
```
`type` ∈ `text|textarea|select|radio|checkbox|number|date|url|email|tel`. Response 200:
```json
{ "answers": [ {"id":"q1","value":"4"}, {"id":"q2","value":null}, {"id":"q3","value":["Arabic","English"]} ] }
```
Every question id comes back exactly once. `value` is a string, an array (checkbox only), or `null` (unknown, which the extension leaves empty). The questions and answers are stored in `details["questions"]` for the tracker and the export. When `AiUsage.answers >= DAILY_ANSWER_LIMIT` it returns 429 `ai_limit_reached`. The extension treats that as `needs_user` for this application and keeps the tab open.

**PATCH `/applications/:id`**. Request:
```json
{ "status": "submitted", "error": null, "details": {"filled":["email","resume"],"unanswered":[],"dry_run":false,"final_url":"https://..."} }
```
Allowed: from `in_progress` to `submitted|failed|needs_user|skipped`, and from `needs_user` to `submitted|skipped|failed` (the user finished it by hand). It sets `finished_at`, and `submitted_at` for submitted. `details` is merged into the stored hash with keys whitelisted (`filled`, `unanswered`, `dry_run`, `final_url`, `captcha`, `login_wall`, `questions`), so it stays under 20 KB. `error` is truncated to 500 chars. Response 200 `{"application": {...same shape as next...}, "today": {"submitted":4,"remaining":6}}`.

CORS: none. The calls come from the extension's service worker, whose `host_permissions` include the Seera origin, so Chrome sends them without CORS preflight checks. Content scripts never call the API directly. They message the worker. This is documented in `extension/README.md` and in a comment in `base_controller.rb`.

## 4. Data

- One migration that only creates tables (A2). No backfill. Nothing existing changes, so old code keeps working, and rollback drops only the new tables.
- `config/schedule.yml` gains one entry. sidekiq-cron's `load_from_hash!` adds it on the next Sidekiq start.
- Export: `UserDataExport#as_json` adds `"auto_apply_preference" => user.auto_apply_preference&.attributes`, `"auto_apply_applications" => applications with posting title/company/url merged`, and `"auto_apply_tokens" => tokens.map { |t| t.attributes.except("token_digest") }`.
- Deletion: FK `on_delete: :cascade` on every user-owned table, plus `dependent:` on the User associations. `ProfilesController#destroy` needs no change. Postings and employers are not personal data and stay.
- Privacy page: no edit in this plan (`pdpl_pages.*` belongs to accounts). There is a follow-up note in Risks.
- Never run seeding, fetching or matching against production from development. Tests use fixtures and stubs only.

## 5. Tests

Unit A (`bin/rails test`, mocha for HTTP and AI):
- `test/models/job_applications/token_test.rb`: issue revokes old, digest-only storage, authenticate ignores revoked.
- `test/models/job_applications/preference_test.rb`: ranges, consent_accepted? only with the current version.
- `test/services/job_applications/gulf_location_test.rb`: English/Arabic cities, ISO codes, "Omaha"/"Romania" negatives, Remote fallback.
- `test/services/job_applications/fetchers/{greenhouse,lever,ashby,workable,smartrecruiters,workday}_test.rb`: `Fetchers::X.any_instance.stubs(:http_get / :http_post).returns(fixture JSON)` from `test/fixtures/files/ats/<ats>.json` (small hand-written samples). They assert the normalised fields, the Gulf filter and pagination stopping.
- `test/services/job_applications/employer_seeder_test.rb`: upsert, deactivate, invalid ats.
- `test/jobs/job_applications/fetch_postings_job_test.rb`: upsert, closes missing postings, continues past one employer's error, enqueues MatchJob, does nothing when the flag env is unset.
- `test/services/job_applications/matcher_test.rb`: prefilter, `stub_ai_response({scores: [...]})`, queued vs approved by mode, below threshold → skipped, daily AI budget respected, no consent/draft resume → nothing.
- `test/services/job_applications/answerer_test.rb`: option not in list → nil, missing ids filled with nil, sensitive questions nil.
- `test/controllers/job_applications/dashboard_controller_test.rb` (+ preferences, tokens, applications): RoutingError when flag off (set `ENV["AUTO_APPLY_ENABLED"]` the same way `test/controllers/coach/chats_controller_test.rb` sets `COACH_TESTERS` (`ENV["AUTO_APPLY_TESTERS"] = @user.email`, `ENV.delete` in teardown)), token shown once, approve/skip/destroy only own rows, en and ar render (`?locale=ar`).
- `test/controllers/api/extension/v1/*_test.rb`: 401 without/with revoked token, 403 flag off, `X-Seera-Token` header only (the Basic `Authorization` header that test_helper adds must not matter), `next` marks in_progress and respects daily_cap, 204 when empty, stale in_progress requeued, answers contract, PATCH transitions + 409, resume.pdf content type (stub `ResumePdfService.generate_pdf`).
- `test/services/resume_builder/public_api_test.rb`: `latest_complete` skips drafts, `pdf` handles bytes and `{path:}`.
- `test/services/user_data_export_test.rb`: new keys present, no token_digest. `test/controllers/profiles_controller_test.rb`: delete removes the auto-apply rows.
- `test/i18n/auto_apply_locales_test.rb`: en/ar key parity.
- System test (optional, `test/system/auto_apply_test.rb`): with the flag on, save prefs with consent, connect extension, see the token.

Unit B (`cd extension && npm test`, which runs `node --test`, no dependencies):
- `labels.test.js`: "First Name*", "الاسم الأول", "E-mail address", "Mobile", "LinkedIn Profile", "Resume/CV", "Cover Letter" map correctly. "Emergency contact phone" does not map to phone. "How did you hear about us" → null.
- `captcha.test.js`: recaptcha/hcaptcha/turnstile iframe and script srcs. A plain page → null. Login wall when there is a password input + "Sign in".
- `delay.test.js`: bounds 60-180 s for rand 0 and 0.999.
- `questions.test.js`: select options extracted, required from `required`/`aria-required`/asterisk, ids stable.

## 6. Risks and checks

| Risk | Check |
|---|---|
| Packwerk: the new pack reaching resume models directly, or accounts naming `JobApplications::*` | `bin/packwerk check`. Only `ResumeBuilder::PublicApi` is used. Accounts already references `Coach::Chat` the same way (enforce_dependencies false). |
| Brakeman: `send_data` of the PDF, redirect to apply_url, mass assignment | Strong params, no user-supplied redirect (apply_url is only shown as a link with `rel="noopener noreferrer nofollow"`). Run `bin/brakeman --no-pager`. |
| `ActionController::API` missing `RateLimiting` or `rate_limit` using the null store in test | Include the module explicitly. The test store is swappable (A11). |
| Header partial breaks for logged-out users | `JobApplications.enabled_for?(nil)` returns false. `home_controller_test` and `pages_controller_test` still pass. |
| ATS feed shape changes or blocks | Each employer fails on its own (`last_error`), Sentry alert, and one bad feed never stops the run. Page limits cap the requests. |
| AI cost | Per-user daily limits on scoring and answers, a 5-per-call batch, and cover letters only for approved applications. |
| AI invents answers | Ruby post-filter on options, sensitive questions forced to null, required gaps → `needs_user` and a human finishes. Default dry-run on first install. |
| Terms of service of job sites | Consent text says so. No CAPTCHA solving, no evasion, human-paced delays, tab visible on needs_user. |
| Token leak | Shown once, digest only, one active per user, revocable, `last_used_at` shown in the dashboard. |
| PDPL: new personal data (answers, cover letters) | Included in export and deletion. Retention of skipped/queued rows is 60 days. Follow-up for the privacy owner: add "auto-apply" to the privacy notice's purposes and recipients (employers) before `AUTO_APPLY_ENABLED=true`. |
| `/auto_apply` reached when the flag is off | The controller raises RoutingError. Covered by a test. |
| Two engineers editing the same file | A owns everything outside `extension/`. B owns only `extension/`. `employers.yml` belongs to a third agent and is read only. |

## 7. Acceptance checklist

- [ ] `bin/rails db:migrate` creates the 6 `auto_apply_*` tables (employers, postings, preferences, applications, tokens, ai_usages), and `db:rollback` removes them.
- [ ] `bin/rails job_applications:seed_employers` upserts `employers.yml`, and a second run reports 0 created.
- [ ] `JobApplications::FetchPostingsJob.perform_now` (flag on, dev) stores only Gulf postings, and one bad employer does not stop it.
- [ ] `config/schedule.yml` has `auto_apply_fetch`, and Sidekiq logs it as loaded.
- [ ] With the flag off: no header link, `/auto_apply` 404s, the API returns 403 `disabled`.
- [ ] With the flag on: prefs save with consent, the token is shown once, revoke works, and the queue's Approve/Skip and the tracker's Delete work. Every string is in English and Arabic, and the RTL layout is correct.
- [ ] Matching creates queued (review) or approved (auto) rows only for scores >= min_score, and stops at the daily AI budget.
- [ ] The API follows section 3.3 exactly, including 204, 409 and 429 `daily_cap_reached`, and uses `X-Seera-Token` only.
- [ ] Profile export contains the auto-apply data without token digests. Account deletion removes it.
- [ ] CI is green: `bin/rubocop`, `bin/brakeman --no-pager`, `bin/importmap audit`, `bin/packwerk check`, `bin/rails db:test:prepare test test:system`.
- [ ] `cd extension && npm test` passes with no installed packages.
- [ ] The extension loads unpacked in Chrome with no manifest errors, pairs with a dev token, shows today's count, and in dry-run fills a Greenhouse test posting and leaves the tab open as `needs_user`.
- [ ] CAPTCHA pages and Workday sign-in pages come back as `needs_user`, never submitted.
- [ ] `extension/README.md` covers install, pairing, dry-run, the server origin (cvcrft.com / localhost:3000), why there is no CORS, and what data is sent where.
