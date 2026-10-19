// Workday (*.myworkdayjobs.com). Applying almost always needs a candidate
// account, so a sign-in or create-account page goes to the user
// (needs_user, error "account_required"). Workday forms are multi-step, so in
// v0.1 the adapter fills the first step it can reach and hands the tab over.
(function (root) {
  "use strict";

  const adapters = (root.SeeraAdapters = root.SeeraAdapters || {});

  const ACCOUNT_TEXT = /\b(sign in|create account|create an account)\b/i;

  function accountRequired(F) {
    if (F.hasPasswordInput(document)) return true;
    const buttons = document.querySelectorAll(
      "[data-automation-id='signInLink'], [data-automation-id='createAccountLink'], [data-automation-id='signInSubmitButton'], [data-automation-id='createAccountSubmitButton']",
    );
    if (Array.from(buttons).some(F.isVisible)) return true;
    const dialog = document.querySelector("[role='dialog'], [data-automation-id='popUpDialog']");
    return Boolean(dialog && F.isVisible(dialog) && ACCOUNT_TEXT.test(F.text(dialog)));
  }

  function handOver(details) {
    return { status: "needs_user", error: "account_required", details: Object.assign({ login_wall: true }, details || {}) };
  }

  adapters.workday = {
    matches: (url) => /(^|\.)myworkdayjobs\.com$/.test(url.hostname) || /(^|\.)myworkday\.com$/.test(url.hostname),
    async run(ctx) {
      const F = root.SeeraFill;
      const captcha = F.preflight();
      if (captcha && captcha.details && captcha.details.captcha) return captcha;
      if (accountRequired(F) || captcha) return handOver();

      const apply = document.querySelector("[data-automation-id='adventureButton']") || F.findClickable(/^apply$/i);
      if (apply) {
        apply.click();
        await F.sleep(2500);
        const manual =
          document.querySelector("[data-automation-id='applyManually']") || F.findClickable(/^apply manually$/i);
        if (manual) {
          manual.click();
          await F.sleep(3000);
        }
      }
      if (accountRequired(F)) return handOver();

      const result = await F.runStandard(Object.assign({}, ctx, { dryRun: true }), {
        formSelectors: ["[data-automation-id='applyFlowPage'] form", "[data-automation-id='applyFlowPage']"],
        formTimeoutMs: 10000,
      });
      if (result.error === "login_wall") return handOver(result.details);
      if (result.status === "needs_user" && !result.error) {
        result.error = "multi_step";
        result.details = Object.assign({}, result.details, { dry_run: Boolean(ctx.dryRun) });
      }
      return result;
    },
  };
})(globalThis);
