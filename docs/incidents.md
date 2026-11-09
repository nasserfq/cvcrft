# Incidents

One entry per production incident, newest first. No blame: what happened, why, what changed so it can't
repeat. Copy the template.

```
## YYYY-MM-DD: short title
- Impact: who noticed what, for how long.
- Cause: the real reason, one line.
- Fix: what stopped it.
- Prevention: the change that stops it happening again (PR link).
```

## 2026-10-29: job CV generation failed on Bedrock (RUBY-RAILS-6)
- Impact: "generate CV for a job" failed for everyone after the switch to Nova Lite.
- Cause: a `max_tokens` above Nova Lite's 10,000 output limit.
- Fix: PR #112 caps every model's `max_tokens`.
- Prevention: model limits live next to the model config; check limits when changing `AI_MODEL`.

## 2026-10-23: Deploy blocked by "Deploy lock found"
- Impact: next Deploy failed until the lock was removed over SSH.
- Cause: a Deploy run was cancelled mid-way and left `.kamal/lock-cvcraft`.
- Fix: `rm -rf .kamal/lock-cvcraft` on the server.
- Prevention: the Deploy workflow now releases the lock when a run fails or is cancelled.

## 2026-10-18: CV analysis cut off (RUBY-RAILS-4)
- Impact: some CV analyses came back incomplete.
- Cause: the model hit `max_tokens` mid-answer.
- Fix: PR #71 (larger budget, split into parts).
- Prevention: AI replies are validated; incomplete ones retry.

## 2026-10-18: Redis connection refused (RUBY-RAILS-3)
- Impact: background jobs and rate limits errored for a few minutes.
- Cause: netcup rebooted the server; Redis came up after the app.
- Fix: containers restarted on their own.
- Prevention: `/up` now checks Redis and Postgres, so UptimeRobot reports it.
