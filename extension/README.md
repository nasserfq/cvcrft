# Seera Auto-apply (Chrome extension)

Applies to the jobs you approved in Seera (`/auto_apply`), on the employer's own
application page, in your own browser. You can watch, stop or take over any tab.
Seera never holds a password for a job site.

## Install (unpacked)

1. Open `chrome://extensions` and turn on **Developer mode**.
2. Click **Load unpacked** and pick this `extension/` folder.
3. Pin "Seera Auto-apply" from the puzzle-piece menu.

## Pair it with your account

1. In Seera, open **Auto-apply**, save your preferences with the consent box
   ticked, then click **Connect extension**. The token (`seera_…`) is shown once.
2. Paste it into the extension popup and click **Save**. The popup calls
   `GET /api/extension/v1/me` and shows your name and today's count.
3. Revoking the token in Seera stops the extension at its next request
   (it clears the token and asks you to pair again).

## Running

- **Start** begins the loop: take the next approved application, open its apply
  page in a background tab, fill it from your CV, upload your CV PDF, ask Seera
  to answer the extra questions (from CV facts only), then submit and report the
  result. **Pause** stops after the current application.
- Between applications it waits 1-3 minutes. When nothing is approved it looks
  again every 30 minutes. When the daily cap is reached it pauses until local
  midnight.
- **Dry run** is on by default after install. In dry run the form is filled but
  never submitted: the tab stays open, the application is reported as
  `needs_user` with `dry_run: true`, and you can check it and submit it yourself.
- A tab that needs you (CAPTCHA, sign-in or account wall, a required question
  the CV cannot answer, validation errors, dry run) is brought to the front, the
  toolbar icon shows "!", and the tab is never closed. Submitted and failed tabs
  close after 5 seconds.

## What it never does

- No CAPTCHA solving and no bot-detection evasion: no fingerprint, user-agent or
  timing tricks. A visible reCAPTCHA, hCaptcha or Turnstile challenge (a
  checkbox or challenge frame with a real size on screen) means the tab goes to
  you before anything is filled. A CAPTCHA script or invisible badge alone does
  not count. If a challenge appears after the submit click instead of a
  confirmation, the application becomes `needs_user` and the tab stays open.
- No logging in or creating accounts. Workday (which nearly always needs a
  candidate account) is handed to you at the sign-in step, and its multi-step
  forms are never submitted by the extension.
- No ticking of consent, legal or sensitive questions (visa, criminal record,
  disability, gender, salary): Seera answers those with `null` and they stay
  empty for you.

## Server origin

The popup's **Advanced → Server** picks `https://cvcrft.com` (default) or
`http://localhost:3000` (development). Both are in `manifest.json`
`host_permissions`. To use any other origin, add it to `host_permissions`
and to `ALLOWED_ORIGINS` in `src/config.js`, then reload the extension.
Changing the server clears the token.

## Why there is no CORS

Only the service worker (`src/background.js`) and the popup call the Seera API.
Both are extension pages, and the Seera origin is in `host_permissions`, so Chrome
sends the requests without a CORS preflight. Requests carry only the
`X-Seera-Token` header, never cookies (`credentials: "omit"`), and the API ignores
sessions. Content scripts on job sites never call the API: they message the
service worker, which checks the message comes from the tab it opened.

## What data goes where

- From Seera to the extension: your CV profile (name, email, phone, city,
  country, LinkedIn, work history, education, skills), your CV PDF and the
  application (job, cover letter). The profile and PDF are kept in
  `chrome.storage.session` (memory only) for the current run.
- From the extension to the employer's site: what it fills in the form, your
  CV PDF and the cover letter. That is the application you consented to.
- From the extension to Seera: the extra questions on the form (label, type,
  options), and the outcome of each application (status, error, which fields
  were filled, unanswered labels, the final URL).
- Stored in `chrome.storage.local`: the token, the server origin, the running
  and dry-run flags, the current application and the last 5 results.

## Supported sites

Greenhouse, Lever, Ashby, Workable, SmartRecruiters and Workday, each with its
own adapter in `src/adapters/`. Other hosts use `generic.js`, but the extension
can only run on hosts listed in `host_permissions`; any other apply page is
reported as `failed` (`inject_failed`).

## Layout

- `src/background.js` service worker loop; all state in `chrome.storage`.
- `src/api.js` API client; `src/config.js` origins, timings, injected files;
  `src/i18n.js` every user-facing string.
- `src/lib/*.js` pure helpers (labels, CAPTCHA/login-wall detection, delay,
  questions). They are plain scripts that register on `globalThis.SeeraLib`, so
  the same files run as content scripts, in the worker and in node tests.
- `src/content/fill.js` DOM helpers and the shared fill/answer/submit flow;
  `src/content/runner.js` picks the adapter and reports back.

## Tests

```sh
cd extension
npm test                     # node --test, no dependencies
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers npm run check:fixtures
```

`check:fixtures` needs Playwright and Chromium. It serves the HTML fixtures in
`test/fixtures/` at Greenhouse, Lever and Workday URLs in a headless page,
injects the content scripts and checks that fields are filled, the PDF lands in
the file input, unknown questions are collected, a visible reCAPTCHA (before or after
submit) and a Workday sign-in give `needs_user`, an invisible reCAPTCHA still submits, and a dry run never submits.
