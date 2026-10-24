# Sentry speed monitoring

Goal: make every page's speed visible in Sentry, comparable before/after each Deploy, and quiet the noise.

Findings (Sentry, last 14 days, org highland-tech, project ruby-rails):
- Browser tracing only runs on the 4 React pages (resume form, coach chat, CV analysis results, LinkedIn import). The landing page (`HomeController#index`, most traffic) and every other ERB page send no web vitals (LCP, INP, CLS).
- Browser page loads are named by raw URL (`/coach/chats/2`), so every chat is its own row.
- No `release` is set, so Sentry can't compare speed before and after a Deploy.
- 20% trace sampling on ~150 requests/day leaves most endpoints with 1 to 5 samples. `bin/load-test` (oha) and the `/up` health check would pollute the numbers at a higher rate.

## Unit 1 (one engineer): server + browser config

Files: `config/initializers/sentry.rb`, `app/frontend/lib/sentry.js`, `app/frontend/entrypoints/monitoring.js` (new), `app/views/layouts/application.html.erb`, test(s) in `test/`.

1. `config/initializers/sentry.rb`
   - `config.release = ENV["SENTRY_RELEASE"].presence || ENV["KAMAL_VERSION"].presence` (Kamal sets KAMAL_VERSION to the deployed git SHA in every app container, web and sidekiq).
   - Replace `traces_sample_rate` with a `traces_sampler`: return 0.0 for the health check (`/up`) and for requests whose User-Agent starts with `oha/` (bin/load-test); otherwise respect `parent_sampled` when present, else `ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "1.0").to_f`. Rack env is in `sampling_context[:env]` for web requests; Sidekiq jobs have no env and get the default rate.
2. Layout `app/views/layouts/application.html.erb`: inside the existing production + SENTRY_DSN block, also render `<meta name="sentry-release">` (same release value, only if present) and `<meta name="sentry-route" content="<controller_path>#<action_name>">` style name matching the server transaction (`"#{controller.class.name}##{action_name}"`, e.g. `HomeController#index`), and `vite_javascript_tag 'monitoring'` so every page loads browser monitoring. Keep it inside the same `if` so dev/test never load it.
3. `app/frontend/entrypoints/monitoring.js`: dynamic `import("../lib/sentry")` after window load + requestIdleCallback, so the ~56 KB gz Sentry chunk never competes with the page (web vitals come from the buffered performance entries). React entrypoints keep importing lib/sentry; the existing `window.__sentry_initialized` guard stops a double init.
4. `app/frontend/lib/sentry.js`:
   - read `release` from the `sentry-release` meta and pass it to `Sentry.init`.
   - `tracesSampleRate: 1.0`.
   - `browserTracingIntegration({ beforeStartSpan: (opts) => ({ ...opts, name: route || opts.name }) })` where `route` comes from the `sentry-route` meta, so page loads group as `HomeController#index`, same name as the server transaction. Only for the pageload (navigation spans are rare here, Turbo is not wired to Sentry; leave them).
5. Test: a unit test for the sampler (lambda extracted so it's testable, e.g. a small `SentryTracesSampler` in `lib/` or `app/lib`; follow where similar helpers live) covering `/up` → 0, oha UA → 0, parent_sampled false → 0, normal → default rate.

No new secrets. No deploy.yml change (KAMAL_VERSION comes from Kamal).
