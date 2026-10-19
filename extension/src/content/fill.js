// DOM helpers shared by every adapter (plan 3.2, steps 1-7). Plain script,
// injected into the job page with chrome.scripting.executeScript({files}).
// Exposes globalThis.SeeraFill.
(function (root) {
  "use strict";

  if (root.SeeraFill) return;

  const { matchStandardField } = root.SeeraLib.labels;
  const { detectCaptcha, detectLoginWall } = root.SeeraLib.captcha;
  const { toQuestion, planAnswer, indexAnswers, isBlank } = root.SeeraLib.questions;

  const CONFIRM_URL = /confirm|thank|submitted|success|application-complete/i;
  const CONFIRM_TEXT = new RegExp(
    [
      "thank you for applying",
      "thanks for applying",
      "thank you for your application",
      "thanks for your application",
      "application (has been )?(submitted|received|sent)",
      "we('ve| have) received your application",
      "your application (has been|was) (submitted|received|sent)",
      "شكرا",
      "شكراً",
      "تم (ارسال|إرسال|استلام) (طلبك|الطلب)",
    ].join("|"),
    "i",
  );
  const ERROR_SELECTOR =
    '[aria-invalid="true"], .error, .errors, .field-error, .field_with_errors, .invalid-feedback, .error-message, [role="alert"], [data-automation-id="errorMessage"]';
  const SKIP_TYPES = new Set(["hidden", "submit", "button", "reset", "image", "password", "search", "file"]);
  const SUBMIT_TEXT = /^(submit( application)?|apply|apply now|send( application)?|submit your application|تقديم|ارسال|إرسال|قدم الآن|تقديم الطلب)$/i;

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  function text(el) {
    return el ? String(el.innerText !== undefined ? el.innerText : el.textContent || "").replace(/\s+/g, " ").trim() : "";
  }

  function isVisible(el) {
    if (!el || !el.isConnected) return false;
    if (el.closest('[aria-hidden="true"], [hidden]')) return false;
    const style = getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden") return false;
    return el.getClientRects().length > 0;
  }

  // --- labels -------------------------------------------------------------

  function textWithout(el, exclude) {
    const clone = el.cloneNode(true);
    clone.querySelectorAll("input, select, textarea, option, button, script, style").forEach((n) => n.remove());
    if (exclude) clone.querySelectorAll(exclude).forEach((n) => n.remove());
    return String(clone.textContent || "").replace(/\s+/g, " ").trim();
  }

  function labelledBy(el) {
    const ids = String(el.getAttribute("aria-labelledby") || "").split(/\s+/).filter(Boolean);
    return ids
      .map((id) => document.getElementById(id))
      .filter(Boolean)
      .map((n) => textWithout(n))
      .join(" ")
      .trim();
  }

  // Label of a single text-like field.
  function labelFor(el) {
    const byAria = labelledBy(el);
    if (byAria) return byAria;
    if (el.labels && el.labels.length) {
      const t = textWithout(el.labels[0]);
      if (t) return t;
    }
    if (el.id) {
      const l = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
      if (l && textWithout(l)) return textWithout(l);
    }
    const aria = el.getAttribute("aria-label");
    if (aria) return aria.trim();
    return containerLabel([el]) || String(el.getAttribute("placeholder") || "").trim();
  }

  // Label of a group (radio/checkbox set) or of a field without its own label:
  // walk up to 5 ancestors and take the first label-like element that does not
  // contain one of the group's inputs.
  function containerLabel(members) {
    const first = members[0];
    const fieldset = first.closest("fieldset");
    if (fieldset) {
      const legend = fieldset.querySelector("legend");
      if (legend && textWithout(legend)) return textWithout(legend);
    }
    let node = first.parentElement;
    for (let depth = 0; node && depth < 5; depth += 1, node = node.parentElement) {
      const candidates = node.querySelectorAll(
        'legend, label, [class*="label"], [class*="Label"], [class*="question-title"], [class*="title"], h3, h4, p, span',
      );
      for (const c of candidates) {
        if (members.some((m) => c.contains(m))) continue;
        if (members.some((m) => m.labels && Array.from(m.labels).some((l) => l === c || l.contains(c)))) continue;
        const t = textWithout(c);
        if (t && t.length <= 300) return t;
      }
    }
    return "";
  }

  function optionLabel(input) {
    if (input.labels && input.labels.length) {
      const t = textWithout(input.labels[0]);
      if (t) return t;
    }
    const aria = input.getAttribute("aria-label");
    if (aria) return aria.trim();
    const next = input.nextElementSibling;
    if (next && textWithout(next)) return textWithout(next);
    return String(input.value || "").trim();
  }

  // --- setting values -----------------------------------------------------

  function nativeSetter(el) {
    const proto =
      el instanceof HTMLTextAreaElement
        ? HTMLTextAreaElement.prototype
        : el instanceof HTMLSelectElement
          ? HTMLSelectElement.prototype
          : HTMLInputElement.prototype;
    const desc = Object.getOwnPropertyDescriptor(proto, "value");
    return desc && desc.set;
  }

  function fire(el, names) {
    for (const name of names) el.dispatchEvent(new Event(name, { bubbles: true }));
  }

  // Native setter + input/change, so React-controlled inputs register it.
  function setValue(el, value) {
    el.focus({ preventScroll: true });
    const setter = nativeSetter(el);
    if (setter) setter.call(el, value);
    else el.value = value;
    fire(el, ["input", "change"]);
    el.dispatchEvent(new Event("blur", { bubbles: true }));
  }

  function setChecked(el, checked) {
    if (el.checked === checked) return;
    el.click();
    if (el.checked !== checked) {
      el.checked = checked;
      fire(el, ["input", "change"]);
    }
  }

  function chooseSelect(select, wanted, loose) {
    const target = String(wanted).trim();
    const options = Array.from(select.options);
    let opt = options.find((o) => text(o) === target || o.textContent.trim() === target);
    if (!opt && loose) {
      const lower = target.toLowerCase();
      opt = options.find((o) => o.value && o.textContent.trim().toLowerCase() === lower);
      if (!opt) opt = options.find((o) => o.value && o.textContent.trim().toLowerCase().startsWith(lower));
    }
    if (!opt) return false;
    setValue(select, opt.value);
    return true;
  }

  function attachFile(input, file) {
    const dt = new DataTransfer();
    dt.items.add(file);
    input.files = dt.files;
    fire(input, ["input", "change"]);
    return input.files.length > 0;
  }

  function isEmpty(el) {
    if (el instanceof HTMLSelectElement) {
      return el.selectedIndex < 0 || !el.value || /^(select|please select|choose|--)/i.test(text(el.options[el.selectedIndex]));
    }
    if (el.type === "file") return !el.files || el.files.length === 0;
    if (el.type === "checkbox" || el.type === "radio") return !el.checked;
    return String(el.value || "").trim() === "";
  }

  // --- step 1: CAPTCHA and login walls --------------------------------------

  // Only what is actually on screen: size, display/visibility/opacity and
  // whether the box overlaps the viewport (challenge frames wait off-screen).
  function onScreen(el) {
    if (!isVisible(el)) return { visible: false, width: 0, height: 0 };
    const rect = el.getBoundingClientRect();
    let node = el;
    while (node && node.nodeType === 1) {
      if (Number(getComputedStyle(node).opacity) === 0) return { visible: false, width: rect.width, height: rect.height };
      node = node.parentElement;
    }
    // Below the fold still counts (the user scrolls); pushed off the page's
    // top or left edge does not.
    const onPage = rect.bottom + scrollY > 0 && rect.right + scrollX > 0;
    return { visible: onPage, width: rect.width, height: rect.height };
  }

  function captchaSignals(doc) {
    const d = doc || document;
    return {
      iframes: Array.from(d.querySelectorAll("iframe")).map((f) =>
        Object.assign({ src: f.src || f.getAttribute("src") || "" }, onScreen(f)),
      ),
      widgets: Array.from(d.querySelectorAll(".g-recaptcha, .h-captcha, .cf-turnstile")).map((el) =>
        Object.assign({ className: el.className, size: el.getAttribute("data-size") || "" }, onScreen(el)),
      ),
    };
  }

  function hasPasswordInput(doc) {
    return Array.from((doc || document).querySelectorAll('input[type="password"]')).some(isVisible);
  }

  // -> null when the page can be filled, or a needs_user result.
  function preflight() {
    const captcha = detectCaptcha(captchaSignals(document));
    if (captcha) return { status: "needs_user", error: "captcha", details: { captcha } };
    const wall = detectLoginWall({
      url: location.href,
      hasPasswordInput: hasPasswordInput(document),
      text: text(document.body).slice(0, 20000),
    });
    if (wall) return { status: "needs_user", error: "login_wall", details: { login_wall: true } };
    return null;
  }

  // --- step 2: helpers to reach the form -------------------------------------

  async function waitFor(fn, timeoutMs, stepMs) {
    const end = Date.now() + (timeoutMs || 10000);
    for (;;) {
      const value = fn();
      if (value) return value;
      if (Date.now() >= end) return null;
      await sleep(stepMs || 250);
    }
  }

  function findClickable(pattern, scope) {
    const nodes = (scope || document).querySelectorAll('a, button, [role="button"], input[type="button"], input[type="submit"]');
    return Array.from(nodes).find((n) => isVisible(n) && pattern.test(text(n) || n.value || n.getAttribute("aria-label") || "")) || null;
  }

  // Most likely application form on the page.
  function findForm(selectors) {
    for (const sel of selectors || []) {
      const el = document.querySelector(sel);
      if (el && el.querySelector("input, textarea, select")) return el;
    }
    let best = null;
    let bestScore = 0;
    for (const form of document.querySelectorAll("form")) {
      const inputs = form.querySelectorAll("input:not([type=hidden]), textarea, select");
      let score = inputs.length;
      if (form.querySelector('input[type="file"]')) score += 10;
      if (form.querySelector('input[type="email"], input[name*="email" i]')) score += 5;
      if (score > bestScore) {
        best = form;
        bestScore = score;
      }
    }
    return best;
  }

  // --- step 3/4: standard fields and files -----------------------------------

  function attrsOf(el) {
    return {
      name: el.getAttribute("name") || "",
      id: el.id || "",
      autocomplete: el.getAttribute("autocomplete") || "",
      ariaLabel: el.getAttribute("aria-label") || "",
      placeholder: el.getAttribute("placeholder") || "",
      type: el.getAttribute("type") || el.tagName.toLowerCase(),
    };
  }

  function profileValues(profile) {
    const p = profile || {};
    const parts = String(p.full_name || "").trim().split(/\s+/).filter(Boolean);
    const first = p.first_name || parts[0] || "";
    const last = p.last_name || parts.slice(1).join(" ");
    return {
      first_name: first,
      last_name: last,
      full_name: p.full_name || [first, last].filter(Boolean).join(" "),
      email: p.email || "",
      phone: p.phone || "",
      city: p.city || "",
      country: p.country || "",
      location: [p.city, p.country].filter(Boolean).join(", "),
      linkedin: p.linkedin_url || "",
    };
  }

  function coverLetterFile(coverLetter) {
    return new File([coverLetter], "Cover_Letter.txt", { type: "text/plain" });
  }

  // Fills name/email/phone/... and attaches the resume and cover letter.
  // Handled elements get data-seera-std so questions skip them.
  function fillStandard(form, ctx) {
    const values = profileValues(ctx.profile);
    const filled = [];
    const fileInputs = [];
    let resumeDone = false;

    const fields = form.querySelectorAll("input, textarea, select");
    for (const el of fields) {
      const type = (el.getAttribute("type") || "").toLowerCase();
      if (["hidden", "submit", "button", "reset", "image", "password", "radio", "checkbox"].includes(type)) continue;
      if (el.disabled || el.readOnly) continue;
      if (type === "file") fileInputs.push(el);
      if (type !== "file" && !isVisible(el)) continue;

      const field = matchStandardField(labelFor(el), attrsOf(el));
      if (!field) continue;

      if (type === "file") {
        if (field === "resume" && ctx.resumeFile && !resumeDone) {
          if (attachFile(el, ctx.resumeFile)) {
            el.dataset.seeraStd = "resume";
            resumeDone = true;
            filled.push("resume");
          }
        } else if (field === "cover_letter" && ctx.coverLetter) {
          if (attachFile(el, coverLetterFile(ctx.coverLetter))) {
            el.dataset.seeraStd = "cover_letter";
            filled.push("cover_letter");
          }
        }
        continue;
      }

      if (field === "resume") continue; // a "paste your resume" box: leave it to the user
      if (field === "cover_letter") {
        if (ctx.coverLetter && el instanceof HTMLTextAreaElement && isEmpty(el)) {
          setValue(el, ctx.coverLetter);
          el.dataset.seeraStd = "cover_letter";
          filled.push("cover_letter");
        }
        continue;
      }

      const value = values[field];
      if (!value || !isEmpty(el)) {
        if (!isEmpty(el)) el.dataset.seeraStd = field;
        continue;
      }
      if (el instanceof HTMLSelectElement) {
        if (chooseSelect(el, value, true)) {
          el.dataset.seeraStd = field;
          filled.push(field);
        }
        continue;
      }
      setValue(el, value);
      el.dataset.seeraStd = field;
      filled.push(field);
    }

    // A form with one unlabelled file input: that is the resume.
    if (!resumeDone && ctx.resumeFile) {
      const free = fileInputs.filter((el) => !el.dataset.seeraStd);
      if (free.length === 1 && fileInputs.length === 1) {
        if (attachFile(free[0], ctx.resumeFile)) {
          free[0].dataset.seeraStd = "resume";
          filled.push("resume");
        }
      }
    }
    return Array.from(new Set(filled));
  }

  // --- step 5: questions ------------------------------------------------------

  let questionCounter = 0;

  // -> {questions: [...], groups: Map id -> [elements], unansweredFiles: [labels]}
  function collectQuestions(form) {
    const questions = [];
    const groups = new Map();
    const unansweredFiles = [];
    const seenNames = new Set();

    const fields = Array.from(form.querySelectorAll("input, textarea, select"));
    for (const el of fields) {
      if (el.dataset.seeraStd || el.disabled || el.readOnly) continue;
      const type = (el.getAttribute("type") || "").toLowerCase();

      if (type === "file") {
        const required = el.required || el.getAttribute("aria-required") === "true" || /[*✱]\s*$/.test(labelFor(el));
        if (required && isEmpty(el)) unansweredFiles.push(labelFor(el) || el.name || "file");
        continue;
      }
      if (SKIP_TYPES.has(type)) continue;

      let members = [el];
      if (type === "radio" || type === "checkbox") {
        const name = el.getAttribute("name");
        if (name) {
          if (seenNames.has(type + ":" + name)) continue;
          seenNames.add(type + ":" + name);
          members = fields.filter((f) => f.getAttribute("type") === type && f.getAttribute("name") === name);
        }
        if (!members.some(isVisible) && !members.some((m) => m.labels && Array.from(m.labels).some(isVisible))) continue;
        if (members.some((m) => m.checked)) continue;
      } else {
        if (!isVisible(el) || !isEmpty(el)) continue;
      }

      const existing = el.dataset.seeraQ;
      const key = existing || String((questionCounter += 1));
      members.forEach((m) => {
        m.dataset.seeraQ = key;
      });

      const lone = (type === "checkbox" || type === "radio") && members.length === 1;
      let label;
      if (type === "radio" || type === "checkbox") {
        label = lone && type === "checkbox" ? optionLabel(el) : containerLabel(members) || labelledBy(el) || el.name;
      } else {
        label = labelFor(el);
      }
      const options =
        el instanceof HTMLSelectElement
          ? Array.from(el.options).filter((o) => o.value !== "").map((o) => o.textContent)
          : type === "radio" || type === "checkbox"
            ? members.map(optionLabel)
            : [];

      const q = toQuestion({
        key,
        label,
        name: el.getAttribute("name") || "",
        tag: el.tagName,
        type: type || el.tagName.toLowerCase(),
        options,
        required: members.some((m) => m.required),
        ariaRequired: members.some((m) => m.getAttribute("aria-required") === "true") ? "true" : "false",
      });
      if (!q.label) continue;
      questions.push(q);
      groups.set(q.id, members);
    }
    return { questions, groups, unansweredFiles };
  }

  function applyAnswers(questions, groups, answers) {
    const index = indexAnswers(questions, answers);
    const applied = [];
    for (const q of questions) {
      const plan = planAnswer(q, index.get(q.id));
      if (plan.kind === "skip") continue;
      const members = groups.get(q.id) || [];
      const el = members[0];
      if (!el) continue;
      if (plan.kind === "text") {
        setValue(el, plan.value);
        applied.push(q.id);
      } else if (el instanceof HTMLSelectElement) {
        if (chooseSelect(el, plan.values[0], false)) applied.push(q.id);
      } else {
        let any = false;
        for (const m of members) {
          if (plan.values.includes(optionLabel(m))) {
            setChecked(m, true);
            any = true;
          }
        }
        if (any) applied.push(q.id);
      }
    }
    return applied;
  }

  function unansweredRequired(questions, groups) {
    return questions
      .filter((q) => q.required)
      .filter((q) => (groups.get(q.id) || []).every((m) => isEmpty(m)))
      .map((q) => q.label);
  }

  // --- step 7: submit and confirmation ----------------------------------------

  function findSubmit(form) {
    const scope = form || document;
    const explicit = Array.from(scope.querySelectorAll('button[type="submit"], input[type="submit"]')).find(isVisible);
    if (explicit) return explicit;
    return findClickable(SUBMIT_TEXT, scope);
  }

  function visibleErrors() {
    return Array.from(document.querySelectorAll(ERROR_SELECTOR)).filter((el) => {
      if (!isVisible(el)) return false;
      if (el.getAttribute("aria-invalid") === "true") return true;
      return text(el).length > 0;
    });
  }

  // Used after submit, and by the service worker after a navigation.
  function pageState() {
    const body = text(document.body).slice(0, 20000);
    let path = "";
    try {
      path = new URL(location.href).pathname + location.search;
    } catch (_e) {
      path = location.href;
    }
    const confirmed = CONFIRM_URL.test(path) || CONFIRM_TEXT.test(body);
    const captcha = detectCaptcha(captchaSignals(document));
    return { confirmed, errors: confirmed ? 0 : visibleErrors().length, captcha, url: location.href };
  }

  async function waitForConfirmation(timeoutMs) {
    const start = Date.now();
    const end = start + (timeoutMs || 20000);
    for (;;) {
      const state = pageState();
      if (state.confirmed) return { status: "submitted" };
      // A challenge shown after the click goes to the user; it is never solved.
      if (state.captcha) return { status: "needs_user", error: "captcha", details: { captcha: state.captcha } };
      if (Date.now() - start > 1500 && state.errors > 0) return { status: "needs_user", error: "validation_errors" };
      if (Date.now() >= end) return { status: "failed", error: "no_confirmation" };
      await sleep(500);
    }
  }

  // --- the whole flow ---------------------------------------------------------

  // opts: {formSelectors: [], openForm: async () => void, formTimeoutMs,
  //        beforeSubmit: (form) -> result|null}
  async function runStandard(ctx, opts) {
    const o = opts || {};
    const blocked = preflight();
    if (blocked) return blocked;

    let form = findForm(o.formSelectors);
    if (!form && o.openForm) {
      await o.openForm();
      form = await waitFor(() => findForm(o.formSelectors), o.formTimeoutMs || 10000);
      const blockedAfter = preflight();
      if (blockedAfter) return blockedAfter;
    }
    if (!form) return { status: "needs_user", error: "form_not_found", details: {} };

    const filled = fillStandard(form, ctx);
    const { questions, groups, unansweredFiles } = collectQuestions(form);

    const details = { filled, unanswered: [], dry_run: Boolean(ctx.dryRun) };
    if (questions.length) {
      let response = null;
      try {
        response = await ctx.api.answers(questions);
      } catch (e) {
        response = { error: (e && e.code) || "answers_failed" };
      }
      if (response && response.error === "ai_limit_reached") {
        details.unanswered = unansweredRequired(questions, groups).concat(unansweredFiles);
        return { status: "needs_user", error: "ai_limit_reached", details };
      }
      const applied = applyAnswers(questions, groups, (response && response.answers) || []);
      if (applied.length) details.filled = details.filled.concat(applied.map((id) => "answer:" + id));
      if (response && response.error) details.answers_error = response.error;
    }

    details.unanswered = unansweredRequired(questions, groups).concat(unansweredFiles);
    if (ctx.resumeFile && !filled.includes("resume")) details.resume_missing = true;
    if (details.unanswered.length) return { status: "needs_user", error: "unanswered_required", details };
    if (ctx.dryRun) return { status: "needs_user", details };

    if (o.beforeSubmit) {
      const stop = o.beforeSubmit(form);
      if (stop) return Object.assign({}, stop, { details: Object.assign({}, details, stop.details || {}) });
    }

    const submit = findSubmit(form);
    if (!submit) return { status: "needs_user", error: "submit_not_found", details };

    if (ctx.onSubmitting) await ctx.onSubmitting();
    submit.click();
    const outcome = await waitForConfirmation(o.confirmTimeoutMs || 20000);
    outcome.details = Object.assign({}, details, outcome.details || {});
    return outcome;
  }

  root.SeeraFill = {
    sleep,
    text,
    isVisible,
    labelFor,
    containerLabel,
    optionLabel,
    setValue,
    setChecked,
    chooseSelect,
    attachFile,
    isEmpty,
    captchaSignals,
    hasPasswordInput,
    preflight,
    waitFor,
    findClickable,
    findForm,
    profileValues,
    fillStandard,
    collectQuestions,
    applyAnswers,
    unansweredRequired,
    findSubmit,
    pageState,
    waitForConfirmation,
    runStandard,
    isBlank,
  };
})(globalThis);
