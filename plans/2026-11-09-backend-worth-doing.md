# Backend "worth doing" items (2026-11-09)

Source: /mnt/project-files/concepts/seera-111-backend-concepts.pdf (26 items marked "Worth doing").
Nasser's rule for this change: **code only, no external changes** (no Cloudflare, AWS, Sentry dashboard,
UptimeRobot, repo-secret or server changes) and **nothing that costs more than the one server**.

Baseline: `bin/rails test` green (1076 runs). Local Postgres + Redis are running.

## Skipped (external or needs a second server)

| # | Item | Why |
|---|---|---|
| 32 | Replication | needs a second server |
| 41 | RAM alert | UptimeRobot/netcup setting |
| 59 | Ship logs off the box | external log service |
| 68 | IAM least privilege | AWS console |
| 74 | WAF rules | Cloudflare dashboard |
| 83 (off-site part) | Copy backups off-server | external storage; restore guide is written instead |
| 110 | Phone push alerts | Nasser's phone/app settings |

## Unit A: AI reliability (circuit breaker #10, backpressure #44)

Owns: new `app/services/ai_circuit.rb` (or inside `packs/ai_tools/app/services/`), the places that call
RubyLLM / Bedrock, `packs/billing/app/services/billing/usage_gate.rb` only if needed for the busy check,
the AI controllers' create actions, locale strings for a "busy" message (en + ar), tests, and
`docs/state-machines.md` if any charge/status flow changes.

- Circuit breaker: after N (5) Bedrock/RubyLLM failures (timeouts, 5xx, throttling, connection errors)
  within 60 s, open for 60 s (state in `Rails.cache`, which is Solid Cache in prod, so web and Sidekiq
  share it). While open: controllers refuse new AI work **before charging** with the busy message
  (429 + same UX as existing rate-limit message), and jobs that start while open re-raise a retryable
  error without calling Bedrock (Sidekiq retry later), never charging twice and never marking failed
  early. A success closes it. Coach included.
- Backpressure: before charging, if the Sidekiq queue that job uses has more than `AI_QUEUE_LIMIT`
  (default 200) enqueued jobs, refuse with the same busy message. Don't block non-AI actions.

## Unit B: observability (#20, #28, #56, #61-64, #93)

Owns: `config/initializers/sidekiq.rb`, `config/sidekiq.yml`, `config/database.yml`,
`app/controllers/application_controller.rb` (health_check only), `config/schedule.yml` (add one entry),
new job `app/jobs/slo_check_job.rb`, new service `app/services/service_levels.rb`, `packs/admin` (a new
read-only Health page behind the existing admin Basic auth), tests.

- #20 Dead jobs: Sidekiq `death_handlers` sends a Sentry message (job class, queue, error class; no args,
  they may hold ids only, keep it PII-free).
- #28 Pool: one source of truth for Sidekiq concurrency; DB pool = max(RAILS_MAX_THREADS,
  SIDEKIQ_CONCURRENCY) + 5 for the CV analysis part threads. Keep current runtime concurrency unchanged
  (find which value actually wins today and keep that number).
- #56 `/up`: checks Postgres (`SELECT 1`) and Redis (`PING`) with short timeouts; 200 JSON when OK,
  503 JSON naming the failing part. Must stay fast, never touch the session/cookies, keep working for
  kamal-proxy and UptimeRobot.
- #61/#64/#93 `ServiceLevels`: for the last 24 h and 7 d, per async kind (cv_generations, cv_analyses,
  ai_translations, cv_imports, linkedin_imports, coach turns if measurable): completed, failed, success
  rate, p50/p95 duration from timestamps; Sidekiq queue sizes, retry and dead counts.
- #63 SLO targets as constants: AI jobs 98% success over 24 h (only when ≥ 20 finished), site uptime
  99.5% (UptimeRobot, shown as text only).
- #62 `SloCheckJob` hourly via sidekiq-cron: reports a Sentry message (warning) when an SLI is below its
  SLO or dead jobs grew. Sentry's default "new issue" email does the alerting; no dashboard change.

## Unit C: release safety (#6, #27, #55, #81, #108)

Owns: `.github/workflows/deploy.yml`, new `.github/workflows/rollback.yml`, `.kamal/hooks/pre-deploy`,
`Gemfile`/`Gemfile.lock` (strong_migrations only), `config/initializers/strong_migrations.rb`,
`config/environments/development.rb`, `config/environments/test.rb`, `Dockerfile`, tests if any.

- #6 Deploy: refuse unless the ref is `main`, and wait for (or verify) a green `CI` run for that exact SHA
  before `kamal deploy`. Release the Kamal lock if the run fails or is cancelled after it took the lock.
  Keep everything else (secrets loading, ssh) as is.
- #55 Rollback workflow: manual, input = version (git SHA, optional; default = previous release found via
  `kamal app containers`/`kamal rollback` semantics), same secret loading as deploy, runs
  `bin/kamal rollback <sha>`. Document that rollback does not undo migrations.
- #81 Pre-deploy hook: before each deploy, `pg_dump` the production DB on the server into
  `/root/cvcraft-db-backup/pre-deploy/` via `docker exec cvcraft-db`, keep the newest 5, fail the deploy if
  the dump fails. Add `strong_migrations` so unsafe migrations fail in dev/test/CI (start_after the
  current latest migration version).
- #27 N+1: `strict_loading_by_default` with `:n_plus_one_only` mode and violations **logged** (not
  raised) in development and test, so nothing breaks.
- #108 Dockerfile: stop deleting `package-lock.json`; use `npm ci` (keep the @parcel/watcher rebuild).
  Verify the lockfile matches package.json (`npm ci --dry-run` or `npm install --package-lock-only` diff
  is empty); if it doesn't, regenerate it with the same npm major used in the image (Node 20) and report.

## Unit D: encryption at rest (#72)

Owns: `config/application.rb` or a new initializer for Active Record encryption keys, the chosen models,
tests. Keys derived from `secret_key_base` via `Rails.application.key_generator` (no new secret), with
`support_unencrypted_data = true` so existing rows stay readable. Encrypt only large free-text PII
columns that are **never** queried, ordered, searched (LIKE/ILIKE/full-text) or indexed. Check every
usage including admin, talent search, data export and retention jobs. If a column is ever queried, leave
it. No data migration of old rows in this change.

## Unit E: docs (#83 restore guide, #109 runbook, #111 incidents, #63 SLOs)

`docs/runbook.md` (where to look, the known fixes: kamal lock, Redis after reboot, max_tokens, rollback),
`docs/restore.md` (restore from nightly or pre-deploy dump, step by step), `docs/incidents.md` (past
incidents, 5 lines each, template), SLO section. Link from AGENTS.md.
