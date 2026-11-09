# State machine fixes, round 2 (2026-11-09)

Follows PR #118 (merged). Source: `/mnt/project-files/state-machines/report.md` sections 6-7 plus the known leftovers.
Nasser's ask: cover everything left, choosing what improves UX, DX and AX, without breaking anything.

Out of scope: coupons (Nasser: leave them as they are), re-consent on policy bump, ledger retention on account deletion, giving back free uses on failure. No new gems, no migrations unless a unit says so, no visible copy changes beyond what a fix needs. Add tests in `test/`.

## Unit A — Resume builder (packs/resume_builder, app/frontend/components/MultiStepResumeForm.jsx final-submit code only)
1. `Resume#save_draft` must not turn a finished resume (`is_draft: false`) back into a draft. Finished resumes keep editing in place.
2. Final submit: when the form came from a draft (it has the draft resume id), finish that draft (update it and `complete_draft`) instead of POSTing a new resume. The FormData fallback re-POST must not create a second resume (make it target the same resume or make create idempotent with a client token). Check every caller/flow before changing; keep request/response shapes the frontend relies on.
3. `resume_draft` finalizes the draft before sending the user to edit it: make it open the draft for editing without marking it finished. `can_be_resumed?` must not be true for a finished resume just because it is <1h old with a blank name.
4. Coach `create_from_draft` (find it via grep; in packs/resume_builder public API): wrap in a transaction so a sync failure leaves no orphan draft.
5. `after_update` PDF job: only enqueue when content fields actually changed (not on every update, e.g. not when only draft flags or timestamps change). Keep behaviour for real edits.
6. `WorkExperiencesController#create` does not permit `job_title` (required), so it can never save. If any UI uses this route, permit the needed fields; if none does, remove the action + route. Report which.
Tests: test/models/resume_test.rb, resumes and work_experiences controller tests, public API tests.

## Unit B — AI tools leftovers (packs/ai_tools)
1. `AiTranslationJob`: skills from the AI come back with string keys but are read with symbol keys (`s[:name]`), so `create_skills_from_translation` and work experience `ats_keywords` never get skills. Read them key-agnostically (`with_indifferent_access` or string keys) and add a test with a realistic string-keyed AI reply.
2. CV generation status/show JSON that the pages poll returns the whole row, including base64 `pdf_data`, `raw_response` and the error backtrace. Return only what the pollers use (find every JS consumer of that JSON first: views under packs/ai_tools/app/views/cv_generations, app/frontend). Never expose the backtrace to users. Keep keys the consumers read.
3. Same check for the analysis/import/translation status endpoints in packs/ai_tools: no backtraces or raw AI responses in user-facing JSON.
Tests: controller tests asserting the trimmed payload and that pollers' keys remain.

## Unit C — Coach (packs/coach, app/frontend coach components)
1. Server guard against overlapping turns: refuse (or queue) a new user message while a turn for the same chat is still running. Use an existing column/lock if one fits (e.g. a row lock on the chat plus "last message is a user message with no assistant reply newer than N minutes"); a stuck turn must not block the chat forever (time limit, e.g. 2 minutes). Return the existing busy/error response the client already handles, or the closest one.
2. `TurnJob` rescues every error and refunds; if the assistant message was already saved, do not refund.
3. `send_to_seera` creates a new resume on every click: make it idempotent per chat (return the resume already created from that chat if it still exists).
Tests: coach controller/job tests.

## Unit D — Agent and developer docs (docs/state-machines.md, AGENTS.md one line)
Written after A-C land: one page listing each state machine (model, column, states, allowed transitions, who writes them, sweeper/refund rules) so humans and agents can change them safely. Link it from AGENTS.md "In this repo".

# Round 2b — findings from the re-audit (2026-11-09)
Same rules as above. Coupons untouched. Prefer existing copy strings (e.g. SeeraProgress "taking longer"/"Check again"); no new user-facing wording unless no existing string fits, then add en+ar i18n keys.

## Unit E1 — CV generation (packs/ai_tools: cv_generations_controller.rb, cv_generator_job.rb, cv_generation_service.rb, cv_generator/*, models/cv_generation.rb, services/cv_generation_pdf_regenerator.rb, views/cv_generations/*; app/frontend/components/CvGenerationShow.jsx + unmounted app/frontend/pages only if dead)
1. Regenerate must never leave a completed row without a usable PDF: build new summary + PDF, write both in one update only on success; on failure keep the old generated content and PDF (don't set pdf_generated false when pdf_data exists). Guard against double runs (claim via conditional update / metadata flag with timeout) and add a rate limit like other AI endpoints. Make it a POST (button_to) if that can be done without breaking the page; keep the GET route answering safely (redirect to show) for old links.
2. Admin CvGenerationPdfRegenerator: PDF-only (re-render from stored generated_data, no AI call), skip ai_model "cv_builder" rows.
3. new.html.erb poll: never show a hard failure on client timeout; after the limit show the existing "taking longer" state with a link to the generation page (it keeps going server-side). Limit should cover server worst case (derive from one constant).
4. destroy of a processing generation cancels it first (cancel! refunds).
5. Retry passes only the job options (slice like regenerate does), and success clears stale error/error_backtrace/pdf_error keys.
6. Exclude ai_model "cv_builder" rows from AI generation lists, the 150 cap and regenerators (until Unit E2 stops creating them; existing rows remain).
7. Remove dead code: CvGenerationShow.jsx / unmounted app/frontend/pages and CvGeneration#complete_draft if truly unreferenced (grep first).

## Unit E2 — Translation + builder export (packs/ai_tools: api/translations_controller.rb, ai_translation_job.rb, models/ai_translation.rb; app/frontend/components/MultiStepResumeForm.jsx translation pollers and export code; packs/resume_builder/app/jobs/cv_builder_pdf_job.rb status/polling bits; routes for /api/pdf_status)
1. Create the AiTranslation row (pending, with job_id) in the controller after validating the text with the model's rules (return the existing validation error, no charge), then charge, then enqueue with the row id. The job loads by id (keep fallback for queued jobs without id). Status endpoint answers from the row truthfully. Sweeper then covers lost jobs.
2. Translation pollers: on client timeout don't drop the result — keep polling less often or show "taking longer / check again" and, when it completes later, apply the result to form state so autosave doesn't overwrite it. Limits cover server worst case.
3. Builder PDF export fallback: remove the form-data POST fallback (show the save error instead); stop creating cv_builder cv_generations rows if nothing needs them (check export_pdf direct_download flow); remove the unreachable job_id/token polling branch and /api/pdf_status + CvBuilderPdfJob.check_pdf_status if unused.

## Unit E3 — Small fixes (app/frontend/components/cv-builder/CvImportModal.jsx; packs/coach chats_controller.rb settle_proposal; packs/accounts send_otp_email_job.rb; packs/resume_builder/app/models/resume.rb PDF callback)
1. CvImportModal: on client timeout show "taking longer / check again" instead of failure; result applied if it completes later.
2. Coach settle_proposal: the Draft::Invalid rescue updates proposals inside the chat lock on a fresh list.
3. SendOtpEmailJob: skip sending if the OTP is verified or expired.
4. Resume after_update CvBuilderPdfJob callback: its output is never read and it overwrites professional_summary_english in the background. Verify nothing reads the cached file; if so, remove the callback (and the before_update tracking added in Unit A) and keep CvBuilderPdfJob for the explicit export path.
