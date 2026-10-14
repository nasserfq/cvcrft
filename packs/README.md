# Packs

The app is a modular monolith: one Rails app, one database, one deploy, with
its features grouped into packs. Each pack has the same `app/` layout as the
main app (`models`, `controllers`, `jobs`, `services`, `helpers`, `views`), and
`config/application.rb` adds every `packs/*/app` to the load paths, so class
names don't change: `packs/accounts/app/models/user.rb` is still `User`.

| Pack | What it owns |
|---|---|
| `accounts` | Users, login codes (OTP), profile, coupons, AI usage limits, SES email |
| `resume_builder` | Resumes and their sections, the builder, PDF templates and export |
| `ai_tools` | Job-based CV generation, CV analysis, translation, the AI client |
| `imports` | CV PDF import and LinkedIn import |
| `billing` | Credits (ledger and balance), credit packs, Moyasar checkout. Off unless `BILLING_ENABLED` |
| `admin` | Administrate dashboards, admin controllers, email load tests |
| `coach` | AI Coach. Off unless `COACH_ENABLED` |

What stays in `app/`: the shared base classes (`ApplicationController`,
`ApplicationRecord`, `ApplicationJob`), the landing, SEO, static pages and
sitemap, the PostHog proxy, locale switching, layouts and shared partials, and
the React frontend in `app/frontend`.

Tests stay in `test/`.

## Adding code

Put new code in the pack whose feature it belongs to, in the same folder it
would have under `app/`. A new pack is a new folder under `packs/` with an
`app/` inside it. It is picked up on the next boot.

Packwerk checks boundaries (`bin/packwerk check` in CI); existing violations live in `package_todo.yml`.
`coach` may only depend on `resume_builder`.
New code in other packs reaches `resume_builder` only through `ResumeBuilder::PublicApi`.
