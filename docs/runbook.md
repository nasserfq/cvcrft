# Runbook: when production breaks

## 1. Where to look

| Question | Look at |
|---|---|
| Is the site up? | UptimeRobot, or open `https://cvcrft.com/up` (it reports `database` and `redis`) |
| What is erroring? | Sentry › Issues (project ruby-rails), newest first; the release tag is the git SHA |
| Are AI jobs succeeding? | `/admin/health` (success rate, p95 time, queues, dead jobs) |
| Stuck or dead jobs? | `/sidekiq` › Retries / Dead |
| Raw logs | Mac: `bin/kamal app logs -f` (web) and `bin/kamal app logs -r worker -f` |
| Server busy? | `ssh -i ~/.ssh/cvcraft_netcup root@159.195.9.248 'uptime; free -m; df -h /'` |

## 2. Known problems and their fix

**Deploy says "Deploy lock found".** The workflow releases it on failure now. If it still happens:

```
ssh -i ~/.ssh/cvcraft_netcup root@159.195.9.248 'rm -rf .kamal/lock-cvcraft'
```

**A release broke something.** Actions › Rollback › Run workflow (leave the version empty for the previous
one). Rollback does not undo migrations; if data must go back too, follow `docs/restore.md`.

**`/up` says redis or database is down** (often after a netcup reboot). Mac:

```
bin/kamal accessory reboot redis
bin/kamal accessory reboot db
bin/kamal app boot
```

**"AI is busy" for everyone.** The AI circuit breaker is open after repeated Bedrock failures; it closes by
itself after a minute. Check Sentry for the Bedrock error (throttling, model access, max_tokens) and the
AWS Health dashboard.

**AI replies cut off / Bedrock validation error.** A `max_tokens` above the model's limit (Nova Lite: 10,000).

**Jobs piling up.** `/admin/health` queue sizes. New AI work is refused above the queue limit, so users see
"busy" instead of waiting forever. Restart the worker: `bin/kamal app boot -r worker`.

## 3. Service levels

| SLI | SLO | Where |
|---|---|---|
| Site uptime | 99.5% per month | UptimeRobot |
| AI jobs completed vs failed (24 h, at least 20 finished) | 98% | `/admin/health`; `SloCheckJob` reports to Sentry hourly when below |

When an SLO is missed two weeks running, fix reliability before new features.

## 4. After an incident

Add five lines to `docs/incidents.md`.
