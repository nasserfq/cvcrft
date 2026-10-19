// Headless check of the adapters against the HTML fixtures in test/fixtures.
// It does not load the extension: it serves each fixture at a real ATS URL
// (so the runner picks the right adapter), injects the content scripts with
// page.addScriptTag and calls SeeraRunner.run with a fake transport.
//
//   PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node scripts/check-fixtures.mjs
//
// Needs Playwright (local or global install). Not part of `node --test`.
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

async function loadPlaywright() {
  try {
    return await import("playwright");
  } catch (_e) {
    const globalRoot = execSync("npm root -g").toString().trim();
    const require = createRequire(path.join(globalRoot, "noop.js"));
    return require("playwright");
  }
}

const CONTENT_FILES = [
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

const ROUTES = {
  "https://job-boards.greenhouse.io/acme/jobs/123": "greenhouse.html",
  "https://job-boards.greenhouse.io/acme/jobs/456": "greenhouse-captcha.html",
  "https://job-boards.greenhouse.io/acme/jobs/789": "greenhouse-invisible.html",
  "https://job-boards.greenhouse.io/acme/jobs/790": "greenhouse-challenge.html",
  "https://jobs.lever.co/acme/abc-123": "lever-posting.html",
  "https://jobs.lever.co/acme/abc-123/apply": "lever.html",
  "https://acme.wd3.myworkdayjobs.com/en-US/careers/job/Riyadh/PM_R1/apply": "workday-signin.html",
};

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n");

const PROFILE = {
  resume_id: 12,
  first_name: "Nasser",
  last_name: "Alfaqih",
  full_name: "Nasser Alfaqih",
  email: "n@example.com",
  phone: "+966500000000",
  city: "Riyadh",
  country: "Saudi Arabia",
  linkedin_url: "https://www.linkedin.com/in/nasser",
};

function payload(dryRun) {
  return {
    application: { id: 345, apply_url: "", cover_letter: "Dear hiring team, I would like to apply." },
    profile: PROFILE,
    resume: { filename: "Nasser_CV.pdf", base64: PDF.toString("base64") },
    dryRun,
  };
}

let failures = 0;
function check(name, condition, info) {
  if (condition) {
    console.log("  ok   " + name);
  } else {
    failures += 1;
    console.log("  FAIL " + name + (info !== undefined ? "  -> " + JSON.stringify(info) : ""));
  }
}

async function runOn(page, url, dryRun) {
  await page.goto(url);
  for (const file of CONTENT_FILES) await page.addScriptTag({ path: path.join(root, file) });
  return page.evaluate(async (p) => {
    window.__questions = [];
    window.__submitting = false;
    const transport = {
      async answers(questions) {
        window.__questions = questions;
        // Stand-in for POST /answers: only "knows" a few facts, null otherwise.
        return {
          answers: questions.map((q) => {
            if (/SQL/.test(q.label)) return { id: q.id, value: "4" };
            if (/authori[sz]ed/i.test(q.label)) return { id: q.id, value: "Yes" };
            if (/^Languages$/.test(q.label)) return { id: q.id, value: ["Arabic", "English", "German"] };
            if (/hear about/i.test(q.label)) return { id: q.id, value: "LinkedIn" };
            if (/tools/i.test(q.label)) return { id: q.id, value: ["SQL", "Excel"] };
            return { id: q.id, value: null };
          }),
        };
      },
      async submitting() {
        window.__submitting = true;
      },
    };
    const picked = window.SeeraRunner.pickAdapter(location.href);
    const result = await window.SeeraRunner.run(p, transport);
    return { adapter: picked && picked.name, result, questions: window.__questions, submitting: window.__submitting };
  }, payload(dryRun));
}

const { chromium } = await loadPlaywright();
const browser = await chromium.launch({ headless: true });
const context = await browser.newContext();
await context.route("**/*", (route) => {
  const url = route.request().url().replace(/[?#].*$/, "").replace(/\/+$/, "");
  const fixture = ROUTES[url];
  if (fixture) {
    return route.fulfill({
      status: 200,
      contentType: "text/html; charset=utf-8",
      body: readFileSync(path.join(root, "test/fixtures", fixture)),
    });
  }
  return route.abort(); // nothing leaves the machine (the reCAPTCHA iframe included)
});

try {
  // 1. Greenhouse, dry run
  {
    console.log("greenhouse (dry run)");
    const page = await context.newPage();
    const out = await runOn(page, "https://job-boards.greenhouse.io/acme/jobs/123", true);
    const r = out.result;
    const values = await page.evaluate(() => {
      const v = (sel) => document.querySelector(sel).value;
      const file = document.querySelector("#resume").files[0];
      return {
        first: v("#first_name"),
        last: v("#last_name"),
        email: v("#email"),
        phone: v("#phone"),
        linkedin: v("#question_1"),
        cover: v("#cover_letter_text"),
        sql: v("#question_2"),
        authorised: document.querySelector("#question_3").selectedOptions[0].textContent,
        hear: document.querySelector("#question_6").selectedOptions[0].textContent,
        salary: v("#question_5"),
        langs: Array.from(document.querySelectorAll("input[name='langs[]']:checked")).map((i) => i.value),
        file: file && { name: file.name, type: file.type, size: file.size },
      };
    });
    check("adapter is greenhouse", out.adapter === "greenhouse", out.adapter);
    check("status needs_user with dry_run", r.status === "needs_user" && r.details.dry_run === true && !r.error, r);
    check("standard fields filled", values.first === "Nasser" && values.last === "Alfaqih" && values.email === "n@example.com" && values.phone === "+966500000000", values);
    check("linkedin + cover letter filled", values.linkedin === PROFILE.linkedin_url && values.cover.startsWith("Dear hiring team"), values);
    check("resume input has the PDF", values.file && values.file.name === "Nasser_CV.pdf" && values.file.type === "application/pdf" && values.file.size === PDF.length, values.file);
    const labels = out.questions.map((q) => q.label);
    check(
      "unknown questions collected",
      ["Years of experience with SQL", "Are you legally authorized to work in Saudi Arabia?", "Languages", "What are your salary expectations?", "How did you hear about this job?"].every((l) => labels.includes(l)) && labels.length === 5,
      out.questions,
    );
    const sel = out.questions.find((q) => q.type === "select" && /authorized/.test(q.label));
    check("select options extracted, required flagged", sel && JSON.stringify(sel.options) === '["Yes","No"]' && sel.required, sel);
    check("answers applied (text/select/checkbox, exact options only)", values.sql === "4" && values.authorised === "Yes" && values.hear === "LinkedIn" && values.langs.join() === "ar,en", values);
    check("null answer left empty", values.salary === "", values.salary);
    check("did not submit", out.submitting === false && (await page.locator("#application-form").count()) === 1);
    await page.close();
  }

  // 2. Greenhouse, live submit
  {
    console.log("greenhouse (submit)");
    const page = await context.newPage();
    const out = await runOn(page, "https://job-boards.greenhouse.io/acme/jobs/123", false);
    check("submitted after confirmation", out.result.status === "submitted" && out.submitting === true, out.result);
    check("final_url reported", out.result.details.final_url === "https://job-boards.greenhouse.io/acme/jobs/123", out.result.details);
    await page.close();
  }

  // 3. Greenhouse with a reCAPTCHA iframe
  {
    console.log("greenhouse + reCAPTCHA");
    const page = await context.newPage();
    const out = await runOn(page, "https://job-boards.greenhouse.io/acme/jobs/456", false);
    const first = await page.inputValue("#first_name");
    check("needs_user with captcha=recaptcha", out.result.status === "needs_user" && out.result.details.captcha === "recaptcha", out.result);
    check("nothing filled, nothing submitted", first === "" && out.submitting === false && out.questions.length === 0, { first });
    await page.close();
  }

  // 3b. Greenhouse with invisible reCAPTCHA (script + badge + hidden challenge frame): submits
  {
    console.log("greenhouse + invisible reCAPTCHA");
    const page = await context.newPage();
    const out = await runOn(page, "https://job-boards.greenhouse.io/acme/jobs/789", false);
    check("submitted (invisible badge is not a CAPTCHA)", out.result.status === "submitted" && out.submitting === true, out.result);
    await page.close();
  }

  // 3c. Visible challenge appears after the submit click instead of a confirmation
  {
    console.log("greenhouse + challenge after submit");
    const page = await context.newPage();
    const started = Date.now();
    const out = await runOn(page, "https://job-boards.greenhouse.io/acme/jobs/790", false);
    const took = Date.now() - started;
    check("needs_user with captcha=recaptcha", out.result.status === "needs_user" && out.result.error === "captcha" && out.result.details.captcha === "recaptcha", out.result);
    check("detected within ~5 s, form left filled", took < 6000 && (await page.inputValue("#first_name")) === "Nasser" && out.submitting === true, { took });
    await page.close();
  }

  // 4. Lever posting page -> navigate to /apply
  {
    console.log("lever posting page");
    const page = await context.newPage();
    const out = await runOn(page, "https://jobs.lever.co/acme/abc-123", true);
    check("asks to navigate to /apply", out.result.navigate === "https://jobs.lever.co/acme/abc-123/apply", out.result);
    await page.close();
  }

  // 5. Lever apply form, required question the CV cannot answer
  {
    console.log("lever apply form");
    const page = await context.newPage();
    const out = await runOn(page, "https://jobs.lever.co/acme/abc-123/apply", false);
    const values = await page.evaluate(() => {
      const v = (sel) => document.querySelector(sel).value;
      const file = document.querySelector("input[name=resume]").files[0];
      return {
        name: v("input[name=name]"),
        email: v("input[name=email]"),
        phone: v("input[name=phone]"),
        linkedin: v("input[name='urls[LinkedIn]']"),
        org: v("input[name=org]"),
        tools: Array.from(document.querySelectorAll("input[name='cards[abc][field1]']:checked")).map((i) => i.value),
        visa: Array.from(document.querySelectorAll("input[name='cards[abc][field0]']")).some((i) => i.checked),
        file: file && file.name,
      };
    });
    check("adapter is lever", out.adapter === "lever", out.adapter);
    check("fields + resume filled", values.name === "Nasser Alfaqih" && values.email === "n@example.com" && values.phone === "+966500000000" && values.linkedin === PROFILE.linkedin_url && values.file === "Nasser_CV.pdf", values);
    const visaQ = out.questions.find((q) => /visa/i.test(q.label));
    check("radio group collected as one required question", visaQ && visaQ.type === "radio" && visaQ.required && JSON.stringify(visaQ.options) === '["Yes","No"]', visaQ);
    check("checkbox answers applied", values.tools.join() === "SQL,Excel", values.tools);
    check("unknown questions collected (company, comments)", out.questions.some((q) => q.label === "Current company") && out.questions.some((q) => q.label === "Additional information"), out.questions.map((q) => q.label));
    check(
      "required unanswered -> needs_user, not submitted",
      out.result.status === "needs_user" && out.result.error === "unanswered_required" && out.result.details.unanswered.some((l) => /visa sponsorship/.test(l)) && !values.visa && out.submitting === false,
      out.result,
    );
    await page.close();
  }

  // 6. Workday sign-in
  {
    console.log("workday sign-in");
    const page = await context.newPage();
    const out = await runOn(page, "https://acme.wd3.myworkdayjobs.com/en-US/careers/job/Riyadh/PM_R1/apply", false);
    check("adapter is workday", out.adapter === "workday", out.adapter);
    check("needs_user account_required", out.result.status === "needs_user" && out.result.error === "account_required" && out.result.details.login_wall === true, out.result);
    check("password field untouched", (await page.inputValue("#password")) === "" && (await page.inputValue("#email")) === "");
    await page.close();
  }
} finally {
  await browser.close();
}

console.log(failures ? `\n${failures} check(s) failed` : "\nall fixture checks passed");
process.exit(failures ? 1 : 0);
