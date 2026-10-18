# CV analysis: speed, live percentage, Seera glass redesign

## Why it is slow (measured)
Sentry, last 30 days, `Sidekiq/CvAnalysisJob`: 5 runs, ~42 s each. 41.5 s of that is one
non-streaming Bedrock `converse` call to Claude Haiku 4.5 that writes the whole JSON report
(5 section scores, strengths, improvements, ATS tips, 5 detailed-feedback paragraphs, keyword
analysis) in one go. Output length dominates; DB/PDF work is milliseconds. The user sees a
spinner with fake steps the whole time, and the page polls every 2 s.

## Fix
1. Split the one call into two calls that run in parallel (threads), each with its own
   max_tokens 8000 (keeps PR #71's intent):
   - Part A "scores": overall_score, section_scores, strengths, improvements, ats_tips
     (kept together so ATS tips cannot contradict ats_compatibility feedback).
   - Part B "details": detailed_feedback, keyword_analysis.
   Merge into the same `analysis_results` shape as today (no view/data contract change).
2. Tighten length: feedback 2-3 sentences, max 3-5 strengths, max 6 improvements, max 5 ATS
   tips, max 10 keywords per list. Shorter output = faster.
3. Stream both calls (RubyLLM `ask` with a block; add block passthrough to `AiModel.complete`).
   Count streamed characters vs an expected size per part/language and write a real
   `progress` (0-100) to a new `cv_analyses.progress` integer column, throttled (~every
   0.75 s), capped at 95 until done; 100 on completion; reset to 0 on (re)start.
   DB writes from threads go through `ActiveRecord::Base.connection_pool.with_connection`.
4. `GET /cv-analysis/:id/status` returns `progress`.

## Design
Pages: `cv_analyses/new`, `processing`, `show` + `CvAnalysisResults.jsx`. Today they are light
(white/slate) and do not match. Rebuild in Seera glass to match `app/views/home/index.html.erb`
exactly: dark forest ground with drifting orbs (`sr-orb*`), `.glass`/`.glass-soft` cards,
`sr-up`/`sr-reveal` entrance animations, `sr-ring` for the score ring, `sr-grow` for bars,
landing typography and buttons. Dark only. RTL/LTR from `language`.
Processing page: big live percentage (number counts up smoothly toward server `progress`,
never backwards) + glass progress bar with shimmer + step labels that light up by percentage.
Poll every 1 s.

## Percentage on other AI waits
A shared partial `app/views/shared/_ai_progress.html.erb` + `window.SeeraProgress` helper:
`SeeraProgress.start(el, {expectedSeconds})` eases toward 95 % by elapsed time,
`.set(el, pct)` for real progress, `.done(el)` jumps to 100. Use it on the LinkedIn import
wait (`packs/imports/app/views/linkedin_imports/new.html.erb`, `status.html.erb`) and the CV
generation wait (`packs/ai_tools/app/views/cv_generations/new.html.erb`).

## Units
- A (backend): migration, `CvAnalysisJob`, `config/initializers/ruby_llm.rb` (`AiModel.complete`
  block passthrough only), `CvAnalysesController#status`, `CvAnalysis` model, tests in `test/`.
- B (frontend): the three cv_analyses views, `CvAnalysisResults.jsx`, the shared partial, the
  LinkedIn import and CV generation wait states.

## Checks
`bin/rubocop`, `bin/rails test` for touched tests, screenshots of new/processing/show
(ar + en, desktop + mobile).
