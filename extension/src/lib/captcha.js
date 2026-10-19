// PURE: CAPTCHA and login-wall detection. The extension never solves or works
// around either one: it hands the tab to the user (status needs_user).
(function (root) {
  "use strict";

  const lib = (root.SeeraLib = root.SeeraLib || {});

  const SRC_PATTERNS = [
    ["recaptcha", /(google\.com|recaptcha\.net|gstatic\.com)\/recaptcha|\/recaptcha\/(api|enterprise)/i],
    ["hcaptcha", /(^|[/.])hcaptcha\.com/i],
    ["turnstile", /challenges\.cloudflare\.com/i],
  ];

  const CLASS_PATTERNS = [
    ["recaptcha", /^(g-recaptcha|grecaptcha-badge|recaptcha-checkbox)$/i],
    ["hcaptcha", /^h-captcha$/i],
    ["turnstile", /^cf-turnstile$/i],
  ];

  // signals: {iframeSrcs: [], scriptSrcs: [], classNames: []}
  // -> "recaptcha" | "hcaptcha" | "turnstile" | null
  function detectCaptcha(signals) {
    const s = signals || {};
    const srcs = [].concat(s.iframeSrcs || [], s.scriptSrcs || []).map(String);
    for (const src of srcs) {
      for (const [kind, pattern] of SRC_PATTERNS) {
        if (pattern.test(src)) return kind;
      }
    }
    for (const name of (s.classNames || []).map(String)) {
      for (const [kind, pattern] of CLASS_PATTERNS) {
        if (pattern.test(name.trim())) return kind;
      }
    }
    return null;
  }

  const LOGIN_TEXT = /\b(sign in|sign-in|signin|log in|log-in|login|create account|create an account|register)\b|تسجيل الدخول|انشاء حساب|إنشاء حساب/i;
  const LOGIN_PATH = /\/(login|log-in|signin|sign-in|sign_in|auth|sso)(\/|\?|#|$)/i;

  // page: {url, hasPasswordInput, text} -> boolean
  function detectLoginWall(page) {
    const p = page || {};
    let path = "";
    try {
      const u = new URL(String(p.url || ""));
      path = u.pathname + u.search;
    } catch (_e) {
      path = String(p.url || "");
    }
    if (LOGIN_PATH.test(path)) return true;
    return Boolean(p.hasPasswordInput) && LOGIN_TEXT.test(String(p.text || ""));
  }

  lib.captcha = { detectCaptcha, detectLoginWall };
})(globalThis);
