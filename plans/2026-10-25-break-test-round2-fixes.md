# Break-test round 2 fixes (2026-10-25)

Round 2 re-ran the five testers on main after PR #92. Findings: "Seera break-test bugs" artifact (round 2 tab). This plan fixes the new critical bugs and the regressions PR #92 introduced.

## 1. Goal
- "Resume draft" on a job-based CV never charges more than once and never re-queues a running job (chaos-r2-n1).
- Typing a skill keeps the whole word (firsttimer-r2-14).
- Full-width text and ligatures print in the PDF instead of vanishing (weird-r2-13, regression from PdfText).
- A long certification name never crashes the PDF (weird-r2-14).
- A certification without an issue date is kept in the final CV (weird-r2-15).
- A hung save never freezes the builder (slow-r2-new-1, regression from auto-save).
- Two tabs on one CV can't silently overwrite each other (chaos-r2-6, made worse by auto-save).

## 2. Approach
- PdfText: normalize with NFKC before mapping, so compatibility characters fold to their ASCII forms.
- Certification rows in the ATS templates: shrink/wrap the text box instead of a fixed box that raises CannotFit.
- Stale-tab protection without a migration: save_draft takes the draft's last-known `updated_at`; when the row moved on, the server answers 409 and the builder shows a short "changed in another tab, reload" state instead of overwriting.
- Save requests get a timeout (AbortController); Next never waits on a hung save.
- resume_draft only resumes a generation that is not already processing/queued, flips the status atomically like retry, and charges once.

## 3. Work units
- A. packs/resume_builder: PdfText NFKC, certification CannotFit, save_draft 409 on stale `updated_at`.
- B. app/frontend: skill input focus, certification without date, save timeout, handling the 409.
- C. packs/ai_tools cv_generations resume_draft.

## 4. Data
No migrations.

## 5. Tests
- A: pdf_text_test for full-width/ligatures; template test with a 200-char certification name; controller test for 409 on stale save_draft.
- B: vite build; Playwright re-run of the round-2 repros.
- C: controller test: two resume_draft calls charge once and queue one job.

## 6. Risks
The 409 must not fire on a tab's own consecutive saves (send back the new `updated_at` in every save response).
