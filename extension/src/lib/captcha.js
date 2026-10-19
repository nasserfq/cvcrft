// PURE: CAPTCHA and login-wall detection. The extension never solves or works
// around either one: it hands the tab to the user (status needs_user).
//
// Only a visible challenge counts: a checkbox or challenge iframe (or widget
// container) with a real size on screen. A CAPTCHA script on its own, the
// invisible reCAPTCHA badge, or a hidden challenge frame waiting off-screen
// does not, because those never ask the user anything until the site decides
// to show a challenge (which is checked again after submit).
(function (root) {
  "use strict";

  const lib = (root.SeeraLib = root.SeeraLib || {});

  const MIN_SIZE = 50; // px; the smallest real widget (Turnstile compact) is ~130x120, reCAPTCHA 304x78

  const IFRAME_PATTERNS = [
    ["recaptcha", /((google\.com|recaptcha\.net)\/recaptcha\/(api2|enterprise)\/(anchor|bframe))/i],
    ["hcaptcha", /(^|[/.])hcaptcha\.com\/.*(checkbox|challenge|hcaptcha\.html)/i],
    ["turnstile", /challenges\.cloudflare\.com\//i],
  ];

  const WIDGET_PATTERNS = [
    ["recaptcha", /^g-recaptcha$/i],
    ["hcaptcha", /^h-captcha$/i],
    ["turnstile", /^cf-turnstile$/i],
  ];

  const INVISIBLE = /size=invisible|checkbox-invisible/i;

  function shown(item) {
    return Boolean(item && item.visible) && Number(item.width) >= MIN_SIZE && Number(item.height) >= MIN_SIZE;
  }

  // signals: {
  //   iframes: [{src, width, height, visible}],
  //   widgets: [{className, width, height, visible, size}]   // size = data-size attribute
  // }
  // -> "recaptcha" | "hcaptcha" | "turnstile" | null
  function detectCaptcha(signals) {
    const s = signals || {};
    for (const frame of s.iframes || []) {
      const src = String((frame && frame.src) || "");
      if (!src || INVISIBLE.test(src) || !shown(frame)) continue;
      for (const [kind, pattern] of IFRAME_PATTERNS) {
        if (pattern.test(src)) return kind;
      }
    }
    for (const widget of s.widgets || []) {
      if (!widget || String(widget.size || "").toLowerCase() === "invisible" || !shown(widget)) continue;
      for (const name of String(widget.className || "").split(/\s+/)) {
        for (const [kind, pattern] of WIDGET_PATTERNS) {
          if (pattern.test(name)) return kind;
        }
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

  lib.captcha = { detectCaptcha, detectLoginWall, MIN_SIZE };
})(globalThis);
