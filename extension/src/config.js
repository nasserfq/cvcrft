// Server origins the extension may talk to. Both are in manifest.json
// host_permissions; any other origin must be added there first (see README).
export const DEFAULT_ORIGIN = "https://cvcrft.com";
export const DEV_ORIGIN = "http://localhost:3000";
export const ALLOWED_ORIGINS = [DEFAULT_ORIGIN, DEV_ORIGIN];
export const API_PATH = "/api/extension/v1";

export const TICK_ALARM = "tick";
export const FIRST_TICK_MINUTES = 0.1;
export const IDLE_RETRY_MS = 30 * 60 * 1000; // nothing approved: look again in 30 min
export const RATE_LIMIT_BACKOFF_MS = 5 * 60 * 1000;
export const ERROR_BACKOFF_MS = 5 * 60 * 1000;
export const WATCHDOG_MS = 60 * 1000; // re-check a running application every minute
export const APPLICATION_TIMEOUT_MS = 10 * 60 * 1000;
export const CLOSE_TAB_AFTER_MS = 5000;
export const MAX_NAVIGATIONS = 3;
export const HISTORY_SIZE = 5;

// Content scripts, in load order: pure libs, DOM helpers, adapters, runner.
export const CONTENT_FILES = [
  "src/lib/labels.js",
  "src/lib/captcha.js",
  "src/lib/questions.js",
  "src/content/fill.js",
  "src/adapters/greenhouse.js",
  "src/adapters/lever.js",
  "src/adapters/ashby.js",
  "src/adapters/workable.js",
  "src/adapters/smartrecruiters.js",
  "src/adapters/workday.js",
  "src/adapters/generic.js",
  "src/content/runner.js",
];

export const CHECK_FILES = ["src/lib/labels.js", "src/lib/captcha.js", "src/lib/questions.js", "src/content/fill.js"];

export function isAllowedOrigin(origin) {
  return ALLOWED_ORIGINS.includes(String(origin || "").replace(/\/+$/, ""));
}

export function normaliseOrigin(origin) {
  const o = String(origin || "").trim().replace(/\/+$/, "");
  return isAllowedOrigin(o) ? o : DEFAULT_ORIGIN;
}
