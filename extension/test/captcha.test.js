import { test } from "node:test";
import assert from "node:assert/strict";
import "../src/lib/captcha.js";

const { detectCaptcha, detectLoginWall } = globalThis.SeeraLib.captcha;

const frame = (src, extra) => Object.assign({ src, width: 304, height: 78, visible: true }, extra || {});

test("visible challenge iframes count", () => {
  assert.equal(detectCaptcha({ iframes: [frame("https://www.google.com/recaptcha/api2/anchor?k=abc&size=normal")] }), "recaptcha");
  assert.equal(detectCaptcha({ iframes: [frame("https://www.recaptcha.net/recaptcha/enterprise/anchor?k=x")] }), "recaptcha");
  assert.equal(detectCaptcha({ iframes: [frame("https://www.google.com/recaptcha/api2/bframe?k=x", { width: 400, height: 580 })] }), "recaptcha");
  assert.equal(detectCaptcha({ iframes: [frame("https://newassets.hcaptcha.com/captcha/v1/abc/static/hcaptcha.html#frame=checkbox")] }), "hcaptcha");
  assert.equal(detectCaptcha({ iframes: [frame("https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b/turnstile/if/ov2/av0", { width: 300, height: 65 })] }), "turnstile");
});

test("visible widget containers count", () => {
  const w = (className, extra) => Object.assign({ className, width: 304, height: 78, visible: true }, extra || {});
  assert.equal(detectCaptcha({ widgets: [w("g-recaptcha")] }), "recaptcha");
  assert.equal(detectCaptcha({ widgets: [w("form-row h-captcha")] }), "hcaptcha");
  assert.equal(detectCaptcha({ widgets: [w("cf-turnstile")] }), "turnstile");
  assert.equal(detectCaptcha({ widgets: [w("g-recaptcha", { size: "invisible" })] }), null);
  assert.equal(detectCaptcha({ widgets: [w("g-recaptcha", { visible: false })] }), null);
});

test("scripts and invisible badges do not count", () => {
  assert.equal(detectCaptcha({ scriptSrcs: ["https://www.google.com/recaptcha/api.js"] }), null);
  assert.equal(detectCaptcha({ iframes: [frame("https://www.google.com/recaptcha/api2/anchor?k=x&size=invisible", { width: 256, height: 60 })] }), null);
  assert.equal(detectCaptcha({ iframes: [frame("https://newassets.hcaptcha.com/captcha/v1/x/static/hcaptcha.html#frame=checkbox-invisible")] }), null);
  // Challenge frame waiting hidden / off-screen / zero-size
  assert.equal(detectCaptcha({ iframes: [frame("https://www.google.com/recaptcha/api2/bframe?k=x", { visible: false })] }), null);
  assert.equal(detectCaptcha({ iframes: [frame("https://challenges.cloudflare.com/x/turnstile", { width: 0, height: 0 })] }), null);
  assert.equal(detectCaptcha({ iframes: [frame("https://www.google.com/recaptcha/api2/anchor?k=x", { width: 10, height: 10 })] }), null);
});

test("a plain page has no CAPTCHA", () => {
  assert.equal(detectCaptcha({}), null);
  assert.equal(detectCaptcha(undefined), null);
  assert.equal(detectCaptcha({ iframes: [frame("https://www.youtube.com/embed/x"), frame("")], widgets: [{ className: "recaptcha-note", width: 300, height: 80, visible: true }] }), null);
});

test("login wall: password input plus sign-in text", () => {
  assert.equal(detectLoginWall({ url: "https://x.myworkdayjobs.com/en-US/site/job/1", hasPasswordInput: true, text: "Sign In to apply" }), true);
  assert.equal(detectLoginWall({ url: "https://x.example.com/apply", hasPasswordInput: true, text: "تسجيل الدخول" }), true);
  assert.equal(detectLoginWall({ url: "https://x.example.com/apply", hasPasswordInput: false, text: "Sign in" }), false);
  assert.equal(detectLoginWall({ url: "https://x.example.com/apply", hasPasswordInput: true, text: "Choose a password for alerts" }), false);
});

test("login wall: login URLs", () => {
  assert.equal(detectLoginWall({ url: "https://careers.example.com/login?next=/apply" }), true);
  assert.equal(detectLoginWall({ url: "https://careers.example.com/users/sign_in" }), true);
  assert.equal(detectLoginWall({ url: "https://jobs.lever.co/acme/123/apply" }), false);
  assert.equal(detectLoginWall({}), false);
});
