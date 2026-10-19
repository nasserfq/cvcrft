// Every user-facing string of the extension, in one place. English only in
// v0.1; add another locale object with the same keys to translate it.
const STRINGS = {
  en: {
    title: "Seera Auto-apply",
    tagline: "Applies to jobs you approved, on the employer's own page.",
    token_label: "Pairing token",
    token_placeholder: "seera_…",
    token_help: "Create it in Seera → Auto-apply → Connect extension.",
    save: "Save",
    saving: "Checking…",
    forget: "Disconnect",
    paired_as: "Connected as {name}",
    start: "Start",
    pause: "Pause",
    running: "Running",
    paused: "Paused",
    today: "Today: {submitted} submitted, {remaining} remaining",
    dry_run: "Dry run (fill forms, never submit)",
    dry_run_short: "dry run",
    dry_run_help: "Filled tabs stay open for you to check and submit yourself.",
    recent: "Recent",
    no_recent: "Nothing yet.",
    advanced: "Advanced",
    server: "Server",
    open_dashboard: "Open Seera dashboard",
    paused_until: "Daily cap reached. Resumes after midnight.",
    working_on: "Working on: {title}",
    needs_you: "A tab needs you: {title}",
    status_submitted: "Submitted",
    status_needs_user: "Needs you",
    status_failed: "Failed",
    status_skipped: "Skipped",
    err_unauthorized: "Token missing or revoked. Create a new one in Seera and paste it here.",
    err_disabled: "Auto-apply is not enabled for your account.",
    err_consent_required: "Accept the auto-apply consent in Seera first.",
    err_not_found: "No finished CV found. Finish one in Seera first.",
    err_network: "Cannot reach the Seera server.",
    err_rate_limited: "Too many requests. Retrying in 5 minutes.",
    err_daily_cap_reached: "Daily cap reached. Resumes after midnight.",
    err_generic: "Something went wrong ({code}).",
  },
};

function pick() {
  const lang = (globalThis.navigator && navigator.language ? navigator.language : "en").slice(0, 2);
  return STRINGS[lang] || STRINGS.en;
}

export function t(key, vars) {
  const dict = pick();
  const template = dict[key] !== undefined ? dict[key] : STRINGS.en[key] !== undefined ? STRINGS.en[key] : key;
  return template.replace(/\{(\w+)\}/g, (_m, name) => (vars && vars[name] !== undefined ? String(vars[name]) : ""));
}

export function errorText(code) {
  const key = "err_" + code;
  return STRINGS.en[key] !== undefined ? t(key) : t("err_generic", { code });
}

export { STRINGS };
