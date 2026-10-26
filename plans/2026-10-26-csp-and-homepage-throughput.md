# CSP header and homepage throughput (2026-10-26)

The live test on cvcrft.com (2026-10-26) found no Content-Security-Policy header, and a homepage ceiling of about 170-200 req/s (no errors, waits grew to 9s). Puma runs WEB_CONCURRENCY=2 and the homepage renders in roughly 10-30 ms, which matches that ceiling.

## 1. Goal
- Every HTML response carries an enforced Content-Security-Policy that blocks scripts, frames and form posts from hosts the app doesn't use, without breaking any page.
- A logged-out homepage visit skips the view render (cached HTML per locale), so the same 2 Puma workers serve several times more visitors.

## 2. Approach
- CSP in config/initializers/content_security_policy.rb. The app has many inline scripts and styles, so allow 'unsafe-inline' for script/style (nonces would need every inline block touched); the value comes from default-src 'self', an explicit host list, object-src 'none', base-uri 'self', frame-ancestors 'self', form-action limited to self + OAuth/Moyasar hosts. Enumerate hosts from the code (Vite, PostHog proxy, Sentry, Google/Apple sign-in, Moyasar, Google Fonts, unpkg for /cv_generations/new incl. Babel's eval).
- Homepage: cache the rendered body for logged-out requests without flash, keyed by locale and a deploy version, in Rails.cache (solid_cache in prod). The CSRF token and anything per-visitor must not be cached into the page.

## 3. Work units
- A. CSP: config/initializers/content_security_policy.rb (+ test).
- B. Homepage cache: app/controllers/home_controller.rb and app/views/home/* (+ test).

## 4. Data
None.

## 5. Tests
- A: integration test that / , /login, /resumes/new, /coach, /credits, /cv_generations/new respond with the header; browse every page in a real browser and assert zero CSP violations.
- B: integration test that a second logged-out GET / doesn't render the view, a logged-in GET / isn't served from cache, locale switch changes the cached copy.

## 6. Risks
A missed host silently breaks a feature in production. Mitigation: page sweep in a browser with securitypolicyviolation listeners.
