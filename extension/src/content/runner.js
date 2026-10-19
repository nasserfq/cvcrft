// Injected entry point. Picks the adapter for this page, runs it with the job
// payload from the service worker and posts the result back. Content scripts
// never call the Seera API: answers go through the worker (seera:answers).
(function (root) {
  "use strict";

  const ORDER = ["greenhouse", "lever", "ashby", "workable", "smartrecruiters", "workday", "generic"];
  const KEEP_DETAILS = ["filled", "unanswered", "dry_run", "final_url", "captcha", "login_wall", "questions"];

  function pickAdapter(href) {
    const url = new URL(href);
    const adapters = root.SeeraAdapters || {};
    for (const name of ORDER) {
      const adapter = adapters[name];
      if (adapter && adapter.matches(url)) return { name, adapter };
    }
    return null;
  }

  function fileFromBase64(resume) {
    if (!resume || !resume.base64) return null;
    const binary = atob(resume.base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return new File([bytes], resume.filename || "CV.pdf", { type: "application/pdf" });
  }

  function cleanResult(result) {
    const r = result || {};
    if (r.navigate) return { navigate: String(r.navigate) };
    const status = ["submitted", "needs_user", "failed", "skipped"].includes(r.status) ? r.status : "failed";
    const details = {};
    for (const key of KEEP_DETAILS) {
      if (r.details && r.details[key] !== undefined) details[key] = r.details[key];
    }
    details.final_url = location.href;
    if (r.details && r.details.dry_run !== undefined) details.dry_run = Boolean(r.details.dry_run);
    return { status, error: r.error ? String(r.error).slice(0, 500) : null, details };
  }

  // payload: {application, profile, resume: {filename, base64}, coverLetter, dryRun}
  // transport: {answers(questions) -> {answers}|{error}, submitting() -> Promise}
  async function run(payload, transport) {
    try {
      const picked = pickAdapter(location.href);
      if (!picked) return cleanResult({ status: "failed", error: "no_adapter" });
      const ctx = {
        application: payload.application,
        profile: payload.profile || {},
        resumeFile: fileFromBase64(payload.resume),
        coverLetter: payload.coverLetter || (payload.application && payload.application.cover_letter) || "",
        dryRun: payload.dryRun !== false,
        api: { answers: (questions) => transport.answers(questions) },
        onSubmitting: () => transport.submitting(),
      };
      const result = await picked.adapter.run(ctx);
      return cleanResult(result);
    } catch (e) {
      return cleanResult({ status: "failed", error: "adapter_error: " + (e && e.message ? e.message : String(e)) });
    }
  }

  root.SeeraRunner = { run, pickAdapter, cleanResult, fileFromBase64 };

  const runtime = root.chrome && root.chrome.runtime;
  if (!runtime || !runtime.onMessage || root.__seeraRunnerListening) return;
  root.__seeraRunnerListening = true;

  const transport = {
    answers: (questions) => runtime.sendMessage({ type: "seera:answers", questions }),
    submitting: () => runtime.sendMessage({ type: "seera:submitting" }),
  };

  runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (!message || message.type !== "seera:run") return false;
    if (root.__seeraRunning) {
      sendResponse({ ok: false, error: "already_running" });
      return false;
    }
    root.__seeraRunning = true;
    sendResponse({ ok: true });
    run(message.payload || {}, transport)
      .then((result) => {
        if (result.navigate) return runtime.sendMessage({ type: "seera:navigate", url: result.navigate });
        return runtime.sendMessage({ type: "seera:result", applicationId: message.payload.application.id, result });
      })
      .finally(() => {
        root.__seeraRunning = false;
      });
    return false;
  });
})(globalThis);
