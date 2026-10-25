# Break-test critical fixes (2026-10-25)

Five parallel break-testers (chaos, weird input, slow phone, sneaky, first-timer) ran the app locally. This plan fixes the 6 critical bugs. The full merged list is in the "Seera break-test bugs" artifact.

## 1. Goal

- Delete account, delete CV and delete draft ask for confirmation again.
- The builder really auto-saves; leaving with unsaved changes warns; a network blip never blanks the form.
- PDF preview/export never 500s on non-Latin-1 characters (Ł, emoji, ✓, →, zero-width).
- Bad work dates are caught in the builder with a clear message; the server answers 422, not 500.
- A failed coach turn refunds the message it was answering, once per message.
- Job-based CV never charges for a job description it will reject, and parallel retries charge once.

## 2. Approach

1. **Stimulus never boots (firsttimer-1).** Stub files in `app/assets/javascripts/` share logical paths with `app/javascript/*` and win in Propshaft's load path, so the importmap serves empty stubs. Delete the stubs; the real files then resolve. The `activestorage.esm.js` stub also shadows the gem's real module.
2. **Builder data loss (firsttimer-2, slow-1).** Debounce the existing `saveDraft` on form changes so "Auto-saved" is true; track dirty state and add a `beforeunload` guard only while dirty; wrap the lazy step `Suspense` in an error boundary that offers retry without unmounting the form state.
3. **PDF glyphs (weird-1).** One `PdfText.sanitize` used by every Prawn writer: transliterate common characters to Windows-1252 and drop the rest. Keeps Helvetica (ATS-safe) rather than embedding a TTF.
4. **Dates (weird-2).** Client check in the work-experience step (start not in the future, end not before start); server paths rescue `ActiveRecord::RecordInvalid` and return 422 with the message.
5. **Coach refund (chaos-1).** The turn job refunds the user message it was enqueued for (by id), not the chat's newest user message; refund key stays idempotent.
6. **Job CV charging (weird-7, chaos-3, slow-3).** Validate the job description before `UsageGate.allow!`; retry flips `failed -> pending` under a row lock and only then charges; retry button disables on submit.

## 3. Work units (disjoint files)

- **A. resume_builder pack:** PDF sanitizer + server-side date error handling (fixes 3, server half of 4).
- **B. app/frontend builder:** auto-save, beforeunload, error boundary, date validation, locale strings (fixes 2, client half of 4).
- **C. app/assets/javascripts + coach pack + ai_tools pack:** fixes 1, 5, 6.

## 4. Data

No migrations.

## 5. Tests

- A: service test that each PDF path renders "Łukasz ✓ → 😀" without raising; controller test for a bad date returning 422.
- B: `vite build` passes; Playwright re-run of the break-test repros.
- C: coach turn job test with two overlapping failed messages refunding both; cv_generations controller tests for short description (no charge) and double retry (one charge); integration check that `Rails.application.assets.load_path.find("application.js")` is `app/javascript/application.js`.

## 6. Risks

- Stimulus booting may wake controllers that never ran before (check `app/javascript/controllers`).
- Auto-save frequency: debounce so typing doesn't spam `save_draft`.
- Re-run all critical repro scripts and the full test suite before merging.
