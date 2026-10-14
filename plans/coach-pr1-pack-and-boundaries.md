# AI Coach PR 1: coach pack, ResumeBuilder::PublicApi, Packwerk boundaries

## Goal
Users see no change in this PR. Developers get a `packs/coach` pack that is switched off unless `COACH_ENABLED` is set (`COACH_TESTERS` lets listed emails in while it is off), one public way into `resume_builder` (`ResumeBuilder::PublicApi`), a `coach` Sidekiq queue, and Packwerk in CI. In CI only new boundary violations fail. Existing ones are recorded in `package_todo.yml`. PR 2 adds controllers, routes and views.

## Approach
Smallest complete change, reusing existing code. `Coach.enabled_for?` is a copy of `Billing.enabled_for?` (packs/billing/app/services/billing.rb:14-20) that reads different env vars. User has no admin role, so the tester email allowlist is how "admin-only" works. `PublicApi` adds no new persistence logic. It reads a resume into the hash that `ResumeDraftSync.sync!` already accepts, and writes through `sync!` itself. That way the builder and the coach always agree on the draft shape. The obvious alternative was a separate coach serializer/importer. That would be a second copy of the section rules, and it would drift from the builder. Packwerk makes the boundary visible without a refactor: only coach enforces dependencies and only resume_builder enforces privacy. Every other pack stays lenient.

Verified against the code:
- Autoload: config/application.rb:33-37 adds each `packs/*/app` to `paths["app"]`, which uses Rails' `{*,*/concerns}` glob. That makes `packs/resume_builder/app/public` an autoload root with no config change, so `app/public/resume_builder/public_api.rb` loads as `ResumeBuilder::PublicApi`. No `ResumeBuilder` constant exists yet, so Zeitwerk creates the module from the directory. Check with `bin/rails zeitwerk:check`.
- `resumes.source` is a string, default "manual", with no inclusion validation (resume.rb:49-67). `"coach"` is safe.
- PDF callback (resume.rb:18-38): `after_create`/`after_update` queue a PDF only when `!is_draft`. So we create with `is_draft: true`, run `sync!` (its save!(validate: false) is skipped because the resume is still a draft), then `update!(is_draft: false)`. That fires exactly one job.
- `WorkExperience#responsibilities` is a plain `text` column with no `serialize`. `sync!` writes an Array, and Rails stores its `to_s` (a JSON-looking string). `read` must parse it back: `JSON.parse` with a newline-split fallback, the same as ats_pdf_generator.rb:132-145. `Skill#skill_names` is `serialize ... coder: JSON`, so it reads back as an Array already.
- config/deploy.yml:44-47 has `BILLING_TESTERS` (non-secret) in `env.clear`, and `BILLING_ENABLED` is not set there. Mirror that by adding only a `COACH_TESTERS:` line with the same comment style. Leave `COACH_ENABLED` unset.

## Work units
1. **Coach module** (owns `packs/coach/app/services/coach.rb`, `config/deploy.yml`). Add `module Coach` with `self.enabled_for?(user)`, identical to Billing's but using `COACH_ENABLED`/`COACH_TESTERS`. Add `COACH_TESTERS: non1993@protonmail.com` under the BILLING lines in deploy.yml env.clear, with a 2-line comment. Ask the lead to confirm that email.
2. **PublicApi** (owns `packs/resume_builder/app/public/resume_builder/public_api.rb`, `test/services/resume_builder/public_api_test.rb`). Write a `module ResumeBuilder::PublicApi` with `module_function`:
   - `read(user, resume_id)`: call `user.resumes.find(resume_id)` and return a string-keyed hash. It has the header keys `complete_name email phone_number city country professional_summary professional_summary_english`, and the section arrays `work_experience` (job_title company start_date end_date is_current responsibilities[]), `education` (degree institution start_date end_date gpa is_current), `skills` (category skill_names[]), `certifications` (name organization date) and `languages` (language proficiency). These are the keys that resume_draft_sync.rb reads.
   - `create_from_draft(user, draft)`: `d = draft.stringify_keys`. Run `user.resumes.create!(complete_name:, email:, phone_number:, city:, country:, is_draft: true, source: "coach")`, so validation of name and email raises `RecordInvalid`. Then `ResumeDraftSync.sync!(resume, d)`, then `resume.update!(is_draft: false)`, and return the resume.
3. **Sidekiq queue** (owns `config/sidekiq.yml`). Add `- [coach, 3]` after `ai_translations`. It is interactive AI like translations, and it ranks below pdf_generation and cv_builder. No job class.
4. **Packwerk** (owns `Gemfile`, `Gemfile.lock`, `packwerk.yml`, `package.yml`, every `packs/*/package.yml`, every generated `package_todo.yml`, `bin/packwerk`, `.github/workflows/ci.yml`, `packs/README.md`). **Depends on 1 and 2.** Run update-todo last, after their code exists.
   - Gemfile `group :development, :test`: add `gem "packwerk", require: false` and `gem "packwerk-extensions", require: false`. Pin to the versions `bundle add` resolves, and read that version's README for config keys.
   - `packwerk.yml`: `include: ["**/*.{rb,rake,erb}"]`, exclude `{bin,node_modules,vendor,tmp,log,public,storage}/**/*` and `app/frontend/**/*`, and `require: [packwerk/privacy/checker]`. Use the require path from the packwerk-extensions README; in 0.3.x it is `packwerk/privacy/checker`.
   - Root `package.yml`: `enforce_dependencies: false`.
   - `packs/{accounts,admin,ai_tools,billing,imports}/package.yml`: `enforce_dependencies: false`.
   - `packs/resume_builder/package.yml`: `enforce_dependencies: false`, `enforce_privacy: true`, `public_path: app/public/`.
   - `packs/coach/package.yml`: `enforce_dependencies: true`, `enforce_privacy: false`, `dependencies: [packs/resume_builder]`. Add `packs/accounts` or `.` only when coach code names `User` or `ApplicationRecord`. In PR 1 it does not, because `enabled_for?` duck-types `user.email`.
   - `bundle binstubs packwerk` creates `bin/packwerk`. Then run `bin/packwerk validate` and `bin/packwerk update-todo`, and commit the generated `package_todo.yml` files.
   - ci.yml: add a `packwerk` job after `lint` with the same checkout and setup-ruby steps, then `bin/packwerk validate` and `bin/packwerk check`.
   - packs/README.md: replace the last paragraph ("Packs can still call each other freely...") with 3 lines. Packwerk checks boundaries (`bin/packwerk check` in CI). Existing violations live in `package_todo.yml`. `coach` may only depend on `resume_builder`. Other packs reach `resume_builder` only through `ResumeBuilder::PublicApi`. Also add a `coach` row to the table: "AI Coach. Off unless `COACH_ENABLED`".

Units 1, 2 and 3 can run in parallel. Unit 4 runs after 1 and 2.

## Data
No migrations. The new `source` value `"coach"` fits the existing string column. Feature flags default to off.

## Tests
- Unit 2: `test/services/resume_builder/public_api_test.rb`. In `setup`, stub `Resume.any_instance.stubs(:queue_pdf_generation)` as in test/services/resume_draft_sync_test.rb:5.
  (a) Round trip: build a draft with one entry per section, with responsibilities and skill_names as arrays. Call `create_from_draft(users(:one), draft)`. Assert `is_draft == false` and `source == "coach"`. Then `read(users(:one), resume.id)` must equal the draft for the header and all five sections. This covers the responsibilities parse.
  (b) `read(users(:two), resume.id)` raises `ActiveRecord::RecordNotFound`.
- Unit 1: no test. It is a verbatim copy of `Billing.enabled_for?`, which test/services/billing already covers. Add one if the lead wants it.
- Units 3 and 4: CI's `bin/packwerk check` is the test.

## Risks
- **Packwerk boots Rails in the lint-style job without a DB.** Initializers that touch Postgres or Redis at boot would fail. Check by running `bin/packwerk check` locally with no DB running. If it fails, give the CI job `RAILS_ENV=test` and the postgres service.
- **ERB parsing.** Packwerk parses the `.erb` views. If any fail to parse, exclude `**/*.erb` and note it in the README.
- **Zeitwerk.** `app/public` becomes an autoload root in every pack. Only resume_builder has one. Run `bin/rails zeitwerk:check`.
- **Draft key drift.** If the builder renames draft keys, `read` silently drops data. The round-trip test catches this.
- **A large `package_todo.yml`.** It is expected and is the baseline. Review the diff to confirm that nothing under `packs/coach` appears.
- **Noticed, not fixed:** config/routes.rb:127 calls `u.admin?`, which User does not define. `/sidekiq` in production raises NoMethodError. Fix it in a separate PR.

## Verify (implementer, in this container)
```
export RBENV_VERSION=3.3.6   # .ruby-version says 3.3.2, which is not installed
bundle install
# throwaway Postgres 16 (root can't run initdb; use the postgres user)
export PG=/usr/lib/postgresql/16/bin D=/tmp/claude-0/pgdata
mkdir -p $D && chown postgres $D
runuser -u postgres -- $PG/initdb -D $D -U postgres --auth=trust
runuser -u postgres -- $PG/pg_ctl -D $D -o "-k /tmp -c listen_addresses=localhost" -l $D/log start
export DATABASE_URL=postgres://postgres@localhost:5432
bin/rails zeitwerk:check
bin/packwerk validate && bin/packwerk check
bin/rubocop && bin/brakeman --no-pager && bin/importmap audit
bin/rails db:test:prepare test test:system   # system tests need Chrome; if absent, run `bin/rails test` and say so
runuser -u postgres -- $PG/pg_ctl -D $D stop
```
Never point `DATABASE_URL` at anything except this local cluster.
