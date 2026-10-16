# SOLID refactor: coach LLM seam, CV generator split, ATS layout dispatch

Date: 2026-10-16. Status: blueprint, nothing implemented.

## 1. Goal

Nothing changes for users. The same prompts go to the same models on the same providers. The CV generator writes the same rows, and every ATS template renders the same PDF bytes. Engineers get four things:

- The coach's three LLM entry points (`Coach::Agent`, `Coach::Extract`, `Coach::Judge`) get their LLM handed in. The provider and model names are written in one file, and tests can pass a fake without stubbing `RubyLLM` globally.
- `CvGeneratorJob` (802 lines) shrinks to orchestration only. Prompt building, response parsing and result persistence become plain objects that can each be tested on their own.
- The admin-only `regenerate_all_pdfs` batch moves out of the user-facing `CvGenerationsController` and into the admin area. `AzureOpenaiService` gets a name that says what it does.
- `AtsTemplatePdfService.generate_pdf` stops switching on `template_key`. Each preset class declares its own layout. `def self.name` overrides are gone from the preset and template classes; they become `display_name`, and `Module#name` works again.

## 2. Approach

### A. Coach LLM seam (DIP)

Add one module, `Coach::Llm` (`packs/coach/app/services/coach/llm.rb`). It is spelled `Llm`, not `LLM`, because the app has no `LLM` inflection acronym. Adding one globally would change how `camelize` treats every `*_llm` file, which is not worth the risk for one constant. The module owns the provider and the model names and exposes four calls:

```ruby
module Coach
  module Llm
    PROVIDER = :bedrock
    MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")
    FAST_MODEL = ENV.fetch("COACH_FAST_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0")
    JUDGE_MODEL = "jev-latest"
    JUDGE_PROVIDER = :typesafe

    module_function

    def chat = RubyLLM.chat(model: MODEL, provider: PROVIDER)
    def fast_chat = RubyLLM.chat(model: FAST_MODEL, provider: PROVIDER)
    def judge? = RubyLLM.config.typesafe_api_key.present?
    def judge(text, questions:) = RubyLLM.judge(text, questions:, model: JUDGE_MODEL, provider: JUDGE_PROVIDER)
  end
end
```

The callers take the LLM as a keyword argument, defaulting to the module:
- `Coach::Agent.new(chat, llm: Coach::Llm)`: `reply` uses `@llm.chat`.
- `Coach::Extract.call(text, llm: Coach::Llm)`: uses `llm.fast_chat`.
- `Coach::Judge.call(draft, llm: Coach::Llm)`, plus `next_step(draft, llm: Coach::Llm)` and `review(draft, llm: Coach::Llm)`. `call` checks `llm.judge?` instead of reading `RubyLLM.config` directly, calls `llm.judge(text, questions:)`, and passes `llm` to `fallback(text, llm)`, which uses `llm.fast_chat`.
- The constants `Agent::MODEL`, `Extract::MODEL` and `Judge::MODEL` are removed. The only reference outside its own file was `judge.rb:46` (`Coach::Extract::MODEL`), and that line becomes `llm.fast_chat`.
- `Coach::Tools::NextStep` and `ReviewCv` keep calling `Coach::Judge.next_step(@chat.draft)` and `Coach::Judge.review(@chat.draft)` without a keyword, so they get the default. `test/services/coach/tools/review_cv_test.rb` asserts `.with(@chat.draft)`, and passing `llm:` there would break that matcher for no gain.

**Why not reuse `AiModel`?** `AiModel` (`config/initializers/ruby_llm.rb:29`) is driven by `AI_PROVIDER` and `AI_MODEL`, which default to `azure` and `gpt-4.1-mini`. Its `chat` also applies `with_temperature(0.7)` by default, while the coach today sends no temperature. Coach also needs a second (fast) model and the Jev judge. Making `AiModel` serve both would mean adding coach-specific knobs to the shared facade that five jobs use, and either the coach or those jobs would change behaviour. A 15-line coach-owned module keeps both identical. `packs/coach/package.yml` already allows `"."`, so nothing changes in Packwerk.

### B. CV generator split (SRP)

`CvGeneratorJob#perform` keeps its signature `(job_description, user_id, resume_id = nil, options = {})`, its `PDF_VERSION`, the private `owned_resume` (`test/integration/security_fixes_test.rb:45` calls it via `send`), the PDF and cache methods, and error handling. Four plain Ruby objects go into `packs/ai_tools/app/services/cv_generator/` (Zeitwerk gives them the `CvGenerator::` namespace). Each body is moved **verbatim**, with ivars turned into constructor args:

| New object | Takes over (current lines) | Interface |
|---|---|---|
| `CvGenerator::ResumeSnapshot` | `format_existing_resume_data` (269-346) | `new(resume_or_nil).to_h` returns `{}` when given nil; the same hash as today |
| `CvGenerator::PromptBuilder` | `build_system_prompt`, `build_existing_cv_context`, `build_user_prompt` (135-267) | `new(job_description:, snapshot:)` with `#system_prompt` and `#user_prompt`. `snapshot` is nil when there is no source resume, which replaces the `@existing_resume` checks |
| `CvGenerator::ResponseParser` | `parse_openai_response` (348-409) | `new(snapshot:).call(message)` returns the same symbol-keyed result hash; it calls `AiModel.token_count` |
| `CvGenerator::ResultPersister` | `update_cv_generation_success` (413-460), `populate_resume_sections` new-resume branch plus the five `populate_*` methods (507-620) | `new(cv_generation).record!(result, snapshot:)` and `#populate_sections!(resume, result)` |

What stays in the job and why:
- `create_new_resume` (`Resume.create!`) and `owned_resume` (`Resume.find_by!`) stay. `::Resume` is a `resume_builder` privacy violation that `packs/ai_tools/package_todo.yml` lists **per file**. Moving the constant into a new file would add a new violation, and `bin/packwerk check` in CI would fail. The new objects only receive resume instances (duck-typed), so they never name `Resume`.
- `generate_pdf_for_resume` and the cache helpers stay, for the same reason (`::AtsTemplatePdfService` is listed in the todo against the job file). Extracting them is a separate follow-up.
- Logging lines move with the code they sit in, so log output is unchanged.

Dead code removed in the same change, with no behaviour change:
- `update_existing_resume`: nothing calls it.
- The `@resume_id` branch of `populate_resume_sections`: it only runs from `create_or_update_resume` when `@resume_id` is nil.
- The commented-out mock classes at lines 10-29.
- The unused `require "net/http"` and `require "uri"`.

The job builds the snapshot once per run (`@snapshot = CvGenerator::ResumeSnapshot.new(@existing_resume).to_h if @existing_resume`). Today the formatter runs up to three times, but nothing writes to the resume between those calls, so all three return the same hash.

**Why plain objects and not concerns?** A concern would only spread the 800 lines over more files that still share the job's ivars. Plain objects with explicit inputs can be tested without Sidekiq or an LLM stub.

### C. Admin batch and `AzureOpenaiService`

**`regenerate_all_pdfs` is broken today.** `User` has no `admin?` method: it is not in `db/schema.rb` and not defined in `packs/accounts`. So `current_user&.admin?` at `cv_generations_controller.rb:459` raises `NoMethodError` (500) for every signed-in user, and the action has never worked. Nothing links to it (no view, JS or test references). The admin area's real gate is HTTP Basic auth in `Admin::ApplicationController`. The plan:
- The loop becomes a `CvGenerationPdfRegenerator.call` service object (`packs/ai_tools/app/services/cv_generation_pdf_regenerator.rb`). It returns `{ total:, success:, failed: }` and keeps the same query, the same `CvGeneratorJob.new.perform(..., { force_pdf_regeneration: true })` call, and the same per-item rescue and logging. It still runs synchronously; changing that is out of scope.
- A new action, `Admin::CvGenerationsController#regenerate_all_pdfs`, protected by the inherited Basic auth. It calls the service and redirects to `admin_cv_generations_path` with notice `t("admin.cv_generations.regenerate_all_pdfs.done", success:, total:, failed:)`. The English text is exactly the current string. The admin area does not run the app's locale switching, so it renders in the default `en`, which is what admins see today.
- Route: inside `namespace :admin`, add `resources :cv_generations do collection { post :regenerate_all_pdfs } end`.
- Old path: the `collection` line becomes `post :regenerate_all_pdfs, to: redirect("/admin/cv_generations/regenerate_all_pdfs", status: 307)`. The 307 keeps the POST and its body, the `regenerate_all_pdfs_cv_generations_path` helper still exists, and the old URL now leads to the admin gate instead of a 500.
- The `current_user&.admin?` check is **not** carried over, because the method does not exist. If a role check is wanted later, it needs a column and a migration, which belongs in a separate plan.

**`AzureOpenaiService` decision: rename, and drop the dead half.** The name is wrong because the class now calls `AiModel`, not Azure. Only `CvGenerationsController` uses it (lines 113, 166, 179, 191, 203, 421), and only its CV-generation methods. Its nine translation methods (`translate_text` … `get_translation_stats`) have **no callers** in `app/`, `packs/`, `lib/` or `test/`. `get_translation_status`, `retry_translation` and `cancel_translation` also look up `AiTranslation.find(id)` without scoping to the user, a latent IDOR. The low-risk move:
- Create `CvGenerationService` (`packs/ai_tools/app/services/cv_generation_service.rb`) with the same `initialize(user_id, resume_id = nil)` and the CV methods copied verbatim (`generate_cv` … `get_cv_generation_stats`).
- Change the six `AzureOpenaiService.new` calls in the controller.
- Delete `azure_openai_service.rb`.
- If the reviewer wants zero deletions, the fallback is to move the translation methods verbatim into `AiTranslationService` instead. Either option is low risk.

### D. ATS layouts on the preset classes (OCP/LSP)

Two class methods go on `AtsStylePresets::Base`. Subclasses override them with the `super.merge` pattern already used for `config`:

```ruby
# Which AtsTemplatePdfService renderer draws this style, and its keyword options.
def self.layout = { renderer: :render_single_column_layout, options: {} }
# Set by presets that render through the legacy AtsPdfGenerator.
def self.legacy_template = nil
```

The override for each preset copies the current `case` branch (`ats_template_pdf_service.rb:36-85`) exactly:

| Preset | `layout` / `legacy_template` |
|---|---|
| `OriginalClassic` | `legacy_template = "classic_01"` (replaces the early return at :23-25) |
| `HarvardClassic` | inherits the default (single column) |
| `WhiteBlackEngineering` | `render_two_column_layout`, `left_width_ratio: 0.28, sidebar_title: "TECH PROFILE", sidebar_sections: [:contact, :skills, :languages], main_sections: [:summary, :education, :work_experience, :certifications]` |
| `SimpleCleanGray` | `render_profile_band_layout`, `band_color: "6B7280"` |
| `MinimalistRealEstate` | `render_two_column_layout`, `0.24`, `"PROFILE SNAPSHOT"`, `[:contact, :languages]`, `[:summary, :education, :skills, :work_experience, :certifications]` |
| `TwoColumnCorporate` | `render_two_column_layout`, `0.32`, `"CORPORATE PROFILE"`, `[:contact, :languages, :skills]`, `[:summary, :education, :work_experience, :certifications]` |
| `BlueMinimalProfessional` | `render_profile_band_layout`, `band_color: "1E3A8A"` |
| `BlackWhiteCorporate` | `render_corporate_layout` |
| `InfographicLight` | `render_infographic_layout` |
| `CleanSingleColumn` | `render_clean_layout` |
| `BusinessAdminModern` | `render_business_admin_layout` |

Add `AtsStyleCatalog.find(key)`, which returns `styles.find { |s| s.key == key } || styles.first`. `generate_pdf` becomes:

```ruby
style = AtsStylePresets::AtsStyleCatalog.find(template_key)
return AtsPdfGenerator.generate_pdf(resume, data, template: style.legacy_template) if style.legacy_template
config = style.config
# ... unchanged filename / path / Prawn::Document.generate / font block ...
layout = style.layout
public_send(layout[:renderer], pdf, resume, data, config, **layout[:options])
```

The `render_*` methods are already public class methods (the file has no `private`), so `public_send` reaches them. The `else` branch only existed as a fallback for unknown keys, and `normalize_template_key` already makes those unreachable. The Base default covers it anyway.

Rename `def self.name` to `def self.display_name` in `ats_style_presets/base.rb`, all 11 presets, `ats_templates/base.rb` and `ats_templates/classic_01.rb`. Today `AtsStylePresets::Base.name` and `AtsTemplates::Base.name` **raise `NotImplementedError`**, and every subclass's `.name` returns a display label instead of the constant name. That breaks `Module#name` for anything that inspects these classes: mocha messages, error reporters, `inspect` in logs. This is the LSP violation.

The callers of the method are only these two (the frontend and tests do not call it):
- `AtsStyleCatalog.catalog`: `name: style.display_name`.
- `AtsPdfGenerator.template_catalog` (`ats_pdf_generator.rb:14`): `name: template.display_name`.

The catalog **hash key stays `:name`**, so `resumes/show.html.erb:25`, `CvGenerationHelper` and `cv_generations/new.html.erb` (which read `template[:name]` / `item[:name]`) need no change.

**Why not a strategy class per layout?** That would be a third hierarchy next to presets and templates. The renderers already exist as methods. The duplicated thing is the key-to-renderer mapping, and it belongs with the preset that already owns that key and its `config`. Adding a template now means one new preset file plus a catalog entry, with no service edit.

## 3. Work units

Four units, each owning disjoint files. All four can start at once; none depends on another.

**Unit 1: coach (`packs/coach` only).**
- Files: `packs/coach/app/services/coach/llm.rb` (new), `agent.rb`, `extract.rb`, `judge.rb`. Tests: `test/services/coach/llm_test.rb` (new), `agent_test.rb`, `extract_test.rb`, `judge_test.rb`.
- Steps:
  1. Add `Coach::Llm` as in 2A.
  2. Add the `llm:` keyword to Agent, Extract and Judge, and drop their `MODEL` constants.
  3. In `judge.rb`, replace `RubyLLM.config.typesafe_api_key.blank?` with `!llm.judge?`, replace `RubyLLM.judge(...)` with `llm.judge(text, questions:)`, and make `fallback` take `llm`.
  4. Keep the `rescue RubyLLM::Error, Faraday::Error` in Judge, because a fake raising those must still fall back.
- Do not touch `tools/*.rb` or `turn_job.rb`; the defaults keep them working.

**Unit 2: CV generator job (`packs/ai_tools`, job plus the new `cv_generator/` folder).**
- Files: `packs/ai_tools/app/jobs/cv_generator_job.rb`, plus new `packs/ai_tools/app/services/cv_generator/resume_snapshot.rb`, `prompt_builder.rb`, `response_parser.rb`, `result_persister.rb`. Tests: `test/jobs/cv_generator_job_test.rb` (new), `test/services/cv_generator/{resume_snapshot,prompt_builder,response_parser,result_persister}_test.rb` (new).
- Steps:
  1. **First**, on the untouched job, write the characterization tests (section 5) and the golden prompt fixtures, and see them pass.
  2. Extract the objects in this order: snapshot, prompt builder, parser, persister. Run the job tests after each one.
  3. Remove the dead code listed in 2B.
  4. Do **not** edit `packs/ai_tools/package_todo.yml`. If `bin/packwerk check` reports a new violation, a `Resume` or `AtsTemplatePdfService` reference leaked into a new file; move it back into the job.
- Must not touch `cv_generations_controller.rb`, `azure_openai_service.rb` or any new service from Unit 3.

**Unit 3: admin batch move and service rename (`packs/ai_tools` controller and services, `packs/admin`, routes, locales).**
- Files:
  - `packs/ai_tools/app/controllers/cv_generations_controller.rb`
  - `packs/ai_tools/app/services/azure_openai_service.rb` (delete)
  - `packs/ai_tools/app/services/cv_generation_service.rb` (new)
  - `packs/ai_tools/app/services/cv_generation_pdf_regenerator.rb` (new)
  - `packs/admin/app/controllers/admin/cv_generations_controller.rb`
  - `config/routes.rb`
  - `config/locales/en.yml`, `config/locales/ar.yml`
  - Tests: `test/controllers/admin/cv_generations_controller_test.rb` (new), `test/services/cv_generation_pdf_regenerator_test.rb` (new), `test/integration/security_fixes_test.rb` (add one case)
- Steps:
  1. Create `CvGenerationService` with the CV methods copied verbatim, change the six call sites, and delete the old file. If the reviewer objects to deleting the uncalled translation methods, use the `AiTranslationService` fallback from 2C instead.
  2. Extract the regenerator service.
  3. Add the admin action and route, plus the 307 redirect on the old path.
  4. Delete `regenerate_all_pdfs` from the user controller.
  5. Add locale keys `admin.cv_generations.regenerate_all_pdfs.done`: en `"PDF regeneration complete: %{success}/%{total} successful, %{failed} failed"`, ar `"اكتملت إعادة إنشاء ملفات PDF: نجح %{success} من %{total}، وفشل %{failed}"`.
  6. No new UI. The action had no button before, and adding one (Seera glass, ar/en) is a follow-up.
- Only this unit edits `config/routes.rb` and `config/locales/*`.

**Unit 4: ATS layouts and `display_name` (`packs/resume_builder` services only).**
- Files:
  - `packs/resume_builder/app/services/ats_style_presets/base.rb`, `ats_style_catalog.rb`, and all 11 preset files
  - `packs/resume_builder/app/services/ats_templates/base.rb`, `classic_01.rb`
  - `packs/resume_builder/app/services/ats_pdf_generator.rb` (line 14 only)
  - `packs/resume_builder/app/services/ats_template_pdf_service.rb`
  - Tests: `test/services/ats_template_pdf_service_test.rb` (extend), `test/services/resume_builder/ats_style_presets_test.rb` (new)
- Steps:
  1. **First**, write the dispatch test and record the PDF digests on the untouched code (section 5).
  2. Add `layout` and `legacy_template` to `Base` and the overrides, add `AtsStyleCatalog.find`, and replace the `case` and the early return in `generate_pdf`.
  3. Rename `name` to `display_name` in the 13 class files and the two catalog builders.
  4. Re-run the digests.
- No view edits are needed (the hash key stays `:name`). If a grep for `\.name\b` on these classes in views or JS finds anything new, fix it in this unit.

## 4. Data

No migrations and no schema changes. Stored formats stay the same:
- `cv_generations.metadata` keeps the same keys and shapes, including `generated_data`, `pdf_cache_key` and `pdf_version`.
- `PDF_VERSION` stays `"2.1"`. The cache key inputs (`complete_name`, `updated_at`, `PDF_VERSION`, template key, MD5 of the data) are unchanged, so existing cached PDFs stay valid.
- `metadata["ats_template"]` keys are unchanged.

Nothing touches production data or secrets. Verification uses the local test database only.

## 5. Tests

All in `test/`. Mocha and `Sidekiq::Testing.fake!` are already set up in `test/test_helper.rb`.

**Unit 1**
- New `test/services/coach/llm_test.rb`:
  - `Coach::Llm.chat` calls `RubyLLM.chat(model: Coach::Llm::MODEL, provider: :bedrock)`.
  - `fast_chat` calls it with `FAST_MODEL`.
  - `judge` passes `model: "jev-latest", provider: :typesafe`.
  - `judge?` follows `RubyLLM.config.typesafe_api_key`.
  - The defaults equal today's literals, which pins the production models.
- `agent_test.rb`: keep the existing `RubyLLM.stubs(:chat)` test (it proves the default path) and add one that passes `llm: fake` with `fake.expects(:chat).returns(chain)`, where `chain` is the existing stub with `RubyLLM.expects(:chat).never`.
- `extract_test.rb` and `judge_test.rb`: keep the current tests, which exercise the default `Coach::Llm` because it calls `RubyLLM.chat` and `RubyLLM.judge`, and add a fake-`llm:` variant of each.
  - Judge needs three variants: `judge?` true calls `fake.judge`, `judge?` false calls `fake.fast_chat` and never `fake.judge`, and `fake.judge` raising `RubyLLM::ServerError` falls back and reports to Sentry.
- Unchanged and must stay green: `test/services/coach/tools/review_cv_test.rb` and `test/jobs/coach/turn_job_test.rb`.

**Unit 2** (characterization first)
- New `test/jobs/cv_generator_job_test.rb`. Use `stub_ai_response`, and `AtsTemplatePdfService.stubs(:generate_pdf)` returning a temp file. Cases:
  - **New CV** (no resume_id): one `Resume` is created with the expected sections, and the `CvGeneration` is `completed` with the expected `generated_content`, `tokens_used` and `metadata["generated_data"]`.
  - **Existing resume:** the resume and its sections are not mutated, `generated_data` equals the snapshot plus the new summary, and the result has `using_existing_data`.
  - **Fenced JSON** in the AI reply is unwrapped.
  - **Non-JSON reply:** the raw text becomes `professional_summary` and the sections are empty.
  - **AI failure:** status is `failed` with `metadata["error"]`, and the error re-raises.
  - **Prompts:** `AiModel.expects(:complete).with(system: golden_system, user: golden_user, temperature: 0.7, max_tokens: 15000)`. Capture `golden_*` from the current code (`job.send(:build_system_prompt)` / `build_user_prompt`) for one fixture resume and for no resume. Store them in `test/fixtures/files/cv_generator/*.txt` so the prompts are byte-identical.
- New unit tests per object in `test/services/cv_generator/`:
  - `ResumeSnapshot`: string vs Array responsibilities, `is_current` gives "Present", and skills grouped by category with `details`.
  - `PromptBuilder`: equals the golden files.
  - `ResponseParser`: the three branches above, plus `tokens_used` from `AiModel.token_count`.
  - `ResultPersister`: the metadata merge keeps prior keys, skill dedupe, and `find_or_initialize_by` keys.
- Unchanged and must stay green: `test/integration/security_fixes_test.rb` (`owned_resume`) and `test/controllers/cv_generations_controller_test.rb`.

**Unit 3**
- New `test/services/cv_generation_pdf_regenerator_test.rb`:
  - Only `completed` rows with `pdf_generated = 'true'` are processed.
  - Rows missing `job_description` count as failed.
  - A raising job counts as failed and the loop continues.
  - Returns the counts.
  - Use `CvGeneratorJob.any_instance.stubs(:perform)`.
- New `test/controllers/admin/cv_generations_controller_test.rb` (Basic auth headers as in `test/integration/admin_pages_test.rb`):
  - Without auth: 401.
  - With auth: calls the regenerator and redirects to `/admin/cv_generations` with the en notice.
- `test/integration/security_fixes_test.rb`: `POST /cv_generations/regenerate_all_pdfs` returns 307 to `/admin/cv_generations/regenerate_all_pdfs` and never calls the regenerator.
- `test/controllers/cv_generations_controller_test.rb`: no edits expected. It stubs `CvGeneratorJob.perform_async`, and the service's `generate_cv` is copied verbatim. Run it to confirm.
- `test/integration/admin_pages_test.rb` must stay green, because the new route sits inside `resources :cv_generations`.

**Unit 4** (dispatch test first)
- New `test/services/resume_builder/ats_style_presets_test.rb`:
  - Every style in `AtsStyleCatalog.styles` has a `display_name` that is a String.
  - `style.name` equals the Ruby constant name (for example `"AtsStylePresets::HarvardClassic"`).
  - `AtsStylePresets::Base.name == "AtsStylePresets::Base"` (today it raises).
  - `AtsTemplates::Classic01.display_name == "Classic 01"`.
  - `AtsTemplatePdfService.template_catalog` returns the same 11 `{key:, name:, description:}` hashes in the same order. Snapshot the array literal from the current code.
  - Every `layout[:renderer]` is a method `AtsTemplatePdfService` responds to.
- `test/services/ats_template_pdf_service_test.rb`: add a data-driven test over the 10 non-legacy keys that sets `AtsTemplatePdfService.expects(<renderer>).with(instance_of(Prawn::Document), @resume, anything, style_config, **expected_options)`. The expected table is written out literally from the current `case`. Also add `original_classic` expecting `AtsPdfGenerator.expects(:generate_pdf).with(@resume, anything, template: "classic_01")`. Write it and run it on the old code first; the same expectations must pass after the refactor. Keep the existing `white_black_engineering` smoke test.
- **PDF byte check (not committed):** before step 2, a throwaway test or runner under the test env renders all 11 keys for the fixture resume and writes `sha256` per key to the scratch dir. Re-run it after the refactor; all 11 digests must match. Prawn writes no timestamp by default. If a digest differs on two runs of the *old* code, compare `PDF::Reader` page text and the object count instead, and note that in the PR.

## 6. Risks and how to check them

| Risk | Unit | Check |
|---|---|---|
| Coach production model or provider drifts | 1 | `llm_test.rb` pins the literals. Grep `rg "RubyLLM\.(chat\|judge)" packs/coach` should match only `llm.rb` |
| A coach fake that does not raise `RubyLLM::Error` skips the fallback path | 1 | Judge fake test raises `RubyLLM::ServerError` |
| Prompt whitespace changes when heredocs move into a class with different indentation (`<<~` strips by the least-indented line) | 2 | Golden prompt files compared byte for byte |
| New Packwerk privacy violation because `Resume` or `AtsTemplatePdfService` is named in a new ai_tools file | 2, 3 | `bin/packwerk validate && bin/packwerk check` with `package_todo.yml` untouched. The regenerator names only `CvGeneration` and `CvGeneratorJob`, both in the same pack |
| `metadata` merge order changes (later keys overwrite earlier ones) | 2 | Job test asserts the full metadata hash |
| Something relied on `regenerate_all_pdfs_cv_generations_path` or the old redirect target | 3 | Repo-wide grep finds no callers. The 307 keeps the path. The only visible change is that the old URL now reaches the Basic-auth gate instead of a 500 |
| CSRF on the redirected POST | 3 | Administrate controllers use `protect_from_forgery`, and the 307 replays the same body and session token. Covered by the integration test |
| Brakeman fingerprints shift because code moved | 3 | `config/brakeman.ignore` lists only `api/translations_controller.rb`, which is not touched. Run `bin/brakeman --no-pager` and expect no new warnings |
| A view or JS reads `.name` off a preset class | 4 | Grep `rg "AtsStylePresets\|AtsTemplates::" app packs` shows only the two catalog builders. The hash key `:name` stays. `resumes_controller_test.rb` and `cv_generations_controller_test.rb` render the pickers |
| PDF output changes (wrong option, ratio typo, renderer typo) | 4 | Dispatch expectations written from the old `case`, plus the 11 before/after digests |
| `public_send` with a renderer symbol from data | 4 | Renderers are literals in class files, not user input; `template_key` is normalized against the catalog first. The presets test asserts each renderer exists |

**Out of scope, but worth telling the user:** `config/routes.rb:140` guards `/sidekiq` in production with `lambda { |u| u.admin? }`, and `User#admin?` does not exist. A signed-in user hitting `/sidekiq` in production most likely gets a 500 rather than a clean refusal. Admins also cannot get in. Fixing it needs a decision (Basic auth like `/admin`, or an admin column), so it is not in this plan.

## CI checks (every unit, before handing to qa-tester)

```
export PG=/usr/lib/postgresql/16/bin D=/tmp/pgdata-solid
mkdir -p $D && chown postgres $D && runuser -u postgres -- $PG/initdb -D $D -U postgres --auth=trust -E UTF8 --locale=C.UTF-8
runuser -u postgres -- $PG/pg_ctl -D $D -o "-k /tmp -c listen_addresses=localhost" -l $D/log start
export DATABASE_URL=postgres://postgres@localhost:5432 PARALLEL_WORKERS=1

bin/rubocop
bin/brakeman --no-pager
bin/importmap audit
bin/packwerk validate && bin/packwerk check
bin/rails db:test:prepare test test:system
```

There are no JS changes, so `bin/vite build` is not needed. There are no Gemfile changes.
