# AI Coach, PRs 2 to 6

Each branch is cut from the previous one and merged in order. Every PR also has to: update `packs/coach/package.yml` deps, keep `bin/packwerk check`, `bin/rubocop` and `bin/brakeman --no-pager -q` clean, put every user-facing string in both `config/locales/{ar,en}.yml` (ERB) and `app/frontend/lib/locales/{ar,en}.json` (React) under `coach.*`, use Seera glass classes (`sr-page glass glass-soft sr-btn sr-primary sr-up`, with `packs/billing/app/views/credits/index.html.erb` as the model), and stay behind `Coach.enabled_for?`. Coach is free: no `Billing::Credits` calls. No Gemfile changes in any PR. Ponytail rule: smallest complete change, reuse what exists.

**Common Verify** (each PR's list adds to this):
```
export PG=/usr/lib/postgresql/16/bin D=/tmp/pgdata-coach
mkdir -p $D && chown postgres $D && runuser -u postgres -- $PG/initdb -D $D -U postgres --auth=trust -E UTF8 --locale=C.UTF-8
runuser -u postgres -- $PG/pg_ctl -D $D -o "-k /tmp -c listen_addresses=localhost" -l $D/log start
export DATABASE_URL=postgres://postgres@localhost:5432 PARALLEL_WORKERS=1
bin/rails db:test:prepare && bin/rails test <new files> && bin/rails test
bin/packwerk validate && bin/packwerk check && bin/rubocop && bin/brakeman --no-pager -q
bin/vite build   # whenever JS changed (there is no `npm run build`; Dockerfile uses npm)
```

Facts checked against the code (2026-10-14):
- `config/application.rb:14` is `# require "action_cable/railtie"`. In Rails 8.1.4 that file does not exist. The correct line is `require "action_cable/engine"`.
- `config/application.rb:49` sets `queue_adapter = :sidekiq` for every env. ActiveJob tests therefore need `def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new` in the test class. Do not change test.rb, because existing tests use `Sidekiq::Testing.fake!`.
- `Procfile.dev` runs no Sidekiq process. Jobs run in a separate `bundle exec sidekiq`, so the dev `async` cable adapter would never see their broadcasts. Dev cable goes to `redis` instead (gem `redis 5.4` is already bundled, and `REDIS_URL` is already used).
- The pack loader (`application.rb:34-38`) adds `packs/*/app`, so every subfolder (`channels`, `services`, ...) is an autoload root. `packs/coach/app/models/coach/chat.rb` resolves to `Coach::Chat`.
- RubyLLM 2.1.0: `us.anthropic.claude-sonnet-4-6` (bedrock) has function_calling, structured_output and streaming. `us.anthropic.claude-haiku-4-5-20251001-v1:0` has structured_output and streaming. There is no per-turn tool-call cap: `with_tool_options(calls:)` only accepts `:one`/`:many`. The cap of 8 is therefore **skipped**. Tool names derive from the class name (`Coach::Tools::SaveSection` → `coach--tools--save_section`), so each tool overrides `def self.tool_name = "save_section"`. `Tool` has no `initialize`, so tools take `initialize(chat)` and are passed as instances to `with_tools`. `response.parsed` returns the JSON for `with_schema`. `RubyLLM.judge(input, questions: {...}, model: "jev-latest")` returns a Judgment: `j[:name].choice`, `j[:name].score`.

---

## PR 2: Chat and agent

**Goal:** A tester opens `/coach`, picks a path, chats, and sees the reply stream in.

**Files**
- `config/application.rb`: uncomment the line as `require "action_cable/engine"`. The default mount is `/cable`, with same-origin checks on.
- `config/cable.yml`: `development: adapter: redis, url: <%= ENV.fetch("REDIS_URL", "redis://localhost:6379/1") %>, channel_prefix: cvcraft_dev`. Test stays `test`, prod stays `solid_cable`.
- `app/channels/application_cable/connection.rb`: `identified_by :current_user`, `connect` sets `self.current_user = env["warden"].user || reject_unauthorized_connection`.
- `app/channels/application_cable/channel.rb`: `class Channel < ActionCable::Channel::Base; end`.
- `packs/coach/app/services/coach.rb`: add `def self.table_name_prefix = "coach_"` (gives `coach_chats`/`coach_messages`) and `def self.broadcast(chat, payload) = ActionCable.server.broadcast("coach:#{chat.id}", payload)`.
- `db/migrate/2026101500000_create_coach_tables.rb`:
  - `coach_chats`: `t.references :user, null: false, foreign_key: { on_delete: :cascade }`, `t.string :path, null: false`, `t.jsonb :draft, null: false, default: {}`, `t.timestamps`.
  - `coach_messages`: `t.references :coach_chat, null: false, foreign_key: { on_delete: :cascade }`, `t.string :role, null: false`, `t.text :content, null: false`, `t.timestamps`, plus index `[:coach_chat_id, :created_at]`.
  - Cascades mean `User` needs no `has_many`, so the accounts pack is not edited.
- `packs/coach/app/models/coach/chat.rb`: `belongs_to :user`, `has_many :messages, class_name: "Coach::Message", foreign_key: :coach_chat_id, inverse_of: :chat`, `PATHS = %w[scratch import]`, `validates :path, inclusion: PATHS`.
- `packs/coach/app/models/coach/message.rb`: `belongs_to :chat, class_name: "Coach::Chat", foreign_key: :coach_chat_id`, `ROLES = %w[user assistant]`, `validates :role, inclusion: ROLES`, `validates :content, presence: true, length: { maximum: 20_000 }`.
- `packs/coach/app/channels/coach/chat_channel.rb`: `subscribed`: `chat = Coach::Chat.find_by(id: params[:chat_id], user: current_user)`, then `chat ? stream_from("coach:#{chat.id}") : reject`.
- `packs/coach/app/services/coach/agent.rb`:
  - `MODEL = ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6")`, `TOOLS = []` (later PRs add classes here).
  - `initialize(chat)`.
  - `reply(&on_text) -> String`: builds `RubyLLM.chat(model: MODEL, provider: :bedrock).with_instructions(instructions).with_tools(*TOOLS.map { _1.new(@chat) })`. It pops the last saved message (it must be role user), `add_message(role: m.role.to_sym, content: m.content)` for the rest in id order, then `ask(last.content) { |c| on_text.call(c.content) if c.content.present? }.content`.
  - `instructions -> String`: a bilingual prompt (reply in the user's language, Arabic or English) plus a per-path paragraph plus `"Current draft (JSON): #{@chat.draft.to_json}"`.
  - The chat is rebuilt from saved text every turn. Tool calls are not persisted; the draft column holds the state.
- `packs/coach/app/jobs/coach/turn_job.rb`: `< ApplicationJob`, `queue_as :coach`.
  - `perform(chat_id)`: `reply = Coach::Agent.new(chat).reply { |t| Coach.broadcast(chat, type: "chunk", text: t) }`, then `msg = chat.messages.create!(role: "assistant", content: reply)`, then `Coach.broadcast(chat, type: "done", message_id: msg.id)`.
  - `rescue => e`: `Sentry.capture_exception(e, tags: { pack: "coach" })`, then `Coach.broadcast(chat, type: "error")`. Nothing re-raises, so Sidekiq never retries and the user never gets a double reply.
- `packs/coach/app/controllers/coach/chats_controller.rb`: `before_action :authenticate_user!, :require_coach!` (raises `ActionController::RoutingError` like `credits_controller.rb:60-62`), and `set_chat` = `Coach::Chat.where(user: current_user).find(params[:id])`.
  - `index`: the two-path start screen.
  - `create`: `path` param, then redirect to show.
  - `show`.
  - `message` (JSON): saves the user message, then `Coach::TurnJob.perform_later(chat.id)`, then `head :accepted`. Blank content returns 422.
- `config/routes.rb`: `namespace :coach do root "chats#index"; resources :chats, only: %i[create show] do post :message, on: :member end end`.
- `packs/coach/app/views/coach/chats/index.html.erb`: two glass cards, each a `button_to coach_chats_path(path:)`.
- `packs/coach/app/views/coach/chats/show.html.erb`: `<div id="coach-chat-root" data-chat-id data-messages='<%= json %>' data-draft='<%= json %>'>` and `vite_javascript_tag 'entrypoints/coach_chat.jsx'`.
- `app/frontend/entrypoints/coach_chat.jsx` mounts `app/frontend/components/coach/CoachChat.jsx`, using the `resume_form.jsx` mount pattern and `lib/i18n.js`. It calls `createConsumer().subscriptions.create({ channel: "Coach::ChatChannel", chat_id }, { received })`. `chunk` appends to the pending bubble, `done` closes it, `error` shows `t("coach.error")`. Input is disabled while a turn runs. Requests are `fetch(POST)` with `X-CSRF-Token` read from the meta tag, as in `CvImportModal.jsx:94`. The layout works in RTL.
- `package.json` (+ `package-lock.json`, `yarn.lock` if the latter still resolves): `npm install @rails/actioncable@<version matching gem 8.1.4>` with a caret, like `@rails/activestorage`.
- `packs/coach/package.yml`: `dependencies: [".", packs/accounts, packs/resume_builder]`.
- Locales: `coach.title`, `coach.paths.scratch|import.{title,body}`, `coach.start`, `coach.placeholder`, `coach.send`, `coach.error`, `coach.thinking`.

**Units:** (A) Rails side, which is everything except the frontend. (B) frontend: `app/frontend/**`, `package*.json`, the json locales.

**Tests**
- `test/models/coach/chat_test.rb`: rejects a path outside PATHS; deleting the user deletes their chats and messages (cascade).
- `test/models/coach/message_test.rb`: role inclusion; content presence.
- `test/channels/coach/chat_channel_test.rb` (`ActionCable::Channel::TestCase`, `stub_connection current_user:`): own chat → `assert_has_stream "coach:#{id}"`; another user's chat → `subscription.rejected?`.
- `test/channels/application_cable/connection_test.rb`: `connect env: { "warden" => stub(user: user) }` sets current_user; with `user: nil` → `assert_reject_connection`.
- `test/jobs/coach/turn_job_test.rb`: `Coach::Agent.any_instance.stubs(:reply).multiple_yields(["He"], ["llo"]).returns("Hello")`. It saves the assistant message and `assert_broadcast_on("coach:#{id}", type: "done", message_id:)`. Error path: `stubs(:reply).raises(RuntimeError)` broadcasts `{type: "error"}`, saves nothing, and `Sentry.expects(:capture_exception)`.
- `test/services/coach/agent_test.rb`: `instructions` contains the draft JSON and differs per path. Do not build the RubyLLM chat here, because building it needs AWS config.
- `test/controllers/coach/chats_controller_test.rb`: off → 404 for index/show/message; `COACH_TESTERS` email → 200; signed out → redirect to sign-in; another user's chat → 404; `message` → 202 and `assert_enqueued_with(job: Coach::TurnJob, queue: "coach")` (needs `queue_adapter_for_test` override); blank → 422.

**Verify:** `bin/vite build`. Locally, with `COACH_ENABLED=true` and Redis running, `bin/dev` plus `bundle exec sidekiq -q coach`: open `/coach` and send a message (AWS keys in env). Chunks stream, and a reload shows the saved history. In the browser devtools a `/cable` websocket is open.

---

## PR 3: Path 1, build from scratch

**Goal:** The coach interviews the user and saves each finished section. A live preview beside the chat fills in.

**Choice:** `extract_facts` and `write_bullets` are **dropped**. Sonnet already reads the user's words and writes the bullets in the arguments it passes to `save_section`, which validates them. A second model call would add cost and latency for nothing. PR 4 adds Haiku extraction where it pays off (a whole CV at once).

**Files**
- `packs/resume_builder/app/public/resume_builder/public_api.rb`: add `REQUIRED = { "work_experience" => %w[job_title company start_date], "education" => %w[degree institution start_date], "skills" => %w[category skill_names], "certifications" => %w[name organization], "languages" => %w[language proficiency] }.freeze`. These are the same keys `ResumeDraftSync` skips on. Also add `FIELDS` per collection (the key lists `read` already slices).
- `packs/coach/app/services/coach/draft.rb`: `module Coach::Draft`, `class Invalid < StandardError`, `SECTIONS = %w[header professional_summary] + PublicApi::REQUIRED.keys`, and `merge(draft, section, value) -> Hash`:
  - `header`: a Hash, sliced to `complete_name email phone_number city country`.
  - `professional_summary`: a non-blank String.
  - Collections: an Array of Hashes, each sliced to `FIELDS[section]`. Every entry must have all `REQUIRED` keys present, and `skill_names`/`responsibilities` must be Arrays. The new list replaces the whole collection.
  - It raises `Invalid` with a message the model can act on.
- `packs/coach/app/services/coach/tools/save_section.rb`: `< RubyLLM::Tool`, `tool_name "save_section"`, `parameter :section`, and `parameter :json` (a string holding the section as JSON).
  - `execute(section:, json:)`: `@chat.update!(draft: Coach::Draft.merge(@chat.draft, section, JSON.parse(json)))`, `Coach.broadcast(@chat, type: "draft", draft: @chat.draft)`, return `"saved"`.
  - On `Invalid`/`JSON::ParserError` it returns `{ error: e.message }` so the model retries.
- `packs/coach/app/services/coach/agent.rb`: `TOOLS = [Coach::Tools::SaveSection]`. The scratch prompt asks one section at a time and calls save_section once the user confirms.
- `app/frontend/components/coach/DraftPreview.jsx`: renders the draft read-only (header, summary, each collection). `CoachChat.jsx` sets the draft on a `draft` event and lays out side-by-side on desktop, stacked on mobile.
- Locales: `coach.preview.*` (section headings, empty state).

**Units:** (A) public_api.rb, draft.rb, the tool, agent.rb. (B) the frontend.

**Tests**
- `test/services/coach/draft_test.rb`: unknown section raises; work_experience entry missing `company` raises; skills with a String `skill_names` raises; a good collection replaces the old one and drops unknown keys; header slices out stray keys.
- `test/services/coach/tools/save_section_test.rb`: valid → `chat.reload.draft` updated and `assert_broadcast_on(..., type: "draft")`; bad JSON / bad section → returns a Hash with `:error` and the draft is unchanged.
- `test/services/resume_builder/public_api_test.rb`: add one round-trip check. A draft that passes `Coach::Draft` goes through `create_from_draft` and then `read`, and every section comes back (this catches drift between REQUIRED and ResumeDraftSync).

**Verify:** a manual chat says "I was a cashier at Panda 2019-2022". The model calls save_section, the preview shows the role, and an invalid call is retried by the model.

---

## PR 4: Path 2, improve an existing CV

**Goal:** The user uploads a PDF or picks one of their Seera CVs. The coach says what it read, suggests rewrites, and the user accepts or rejects each one.

**Choices:**
- PDF only. There is no docx gem, so the UI says "Word: save as PDF first".
- `load_seera_cv` is **a form select, not a tool**. The import card lists the user's resumes, and picking one copies `PublicApi.read` into the draft in the controller. This is deterministic, needs no LLM round-trip, and cannot reach another user's resume because of `user.resumes.find`.
- Proposals get their own column rather than `draft["_proposals"]`, so `Coach::Draft` and `create_from_draft` never see them.

**Files**
- `db/migrate/2026101600000_add_proposals_to_coach_chats.rb`: `add_column :coach_chats, :proposals, :jsonb, null: false, default: []`. This is additive, so it is safe.
- `public_api.rb`: `list(user) -> [{ "id", "title", "updated_at" }]` from `user.resumes.order(updated_at: :desc)`, with title = `title.presence || complete_name`.
- `packs/coach/app/services/coach/extract.rb`: `Coach::Extract.call(text) -> Hash`. It runs `RubyLLM.chat(model: ENV.fetch("COACH_FAST_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0"), provider: :bedrock).with_schema(Coach::Draft.json_schema).ask(text.first(LinkedinPdfParserService::MAX_TEXT_CHARS)).parsed`. Each section is then passed through `Coach::Draft.merge` (invalid entries are dropped). Add `Coach::Draft.json_schema` (a plain Hash) in draft.rb.
- `chats_controller.rb`:
  - `create` with `path: "import"` takes either `resume_id`, which sets `draft = PublicApi.read(current_user, id)` and saves the user message `t("coach.import.review_seera", title:)`, or `pdf_file`. For a PDF it applies the same content-type and ≤10MB checks as `cv_imports_controller.rb:19-32`, runs `CvPdfImportService.new(file.path).parse[:text]`, and saves it as the first user message. It does not reject Arabic. It then enqueues TurnJob.
  - New `accept`/`reject` (JSON, `params[:proposal_id]`). `accept` writes `after` into the draft at `section`/`index`/`field` through `Coach::Draft.merge` (which re-validates), removes the proposal, and broadcasts `draft`. `reject` only removes it.
- `turn_job.rb`: before the agent runs, `if chat.path == "import" && chat.draft.blank?` it sets `chat.update!(draft: Coach::Extract.call(chat.messages.first.content))` and broadcasts `draft`. This is async, so the request never waits on the LLM.
- `packs/coach/app/services/coach/tools/propose_rewrite.rb`: params `section`, `index` (optional, for collections), `field`, `after`.
  - It reads `before` from the draft and errors if the path doesn't exist.
  - It appends `{ "id" => SecureRandom.hex(4), section, index, field, before, after }` to `chat.proposals` and broadcasts `{type: "proposal", proposal}`.
  - Fields are limited to `professional_summary` and `work_experience[].responsibilities`, which is where rewrites matter.
- `agent.rb`: `TOOLS += [Coach::Tools::ProposeRewrite]`. The import prompt goes: first summarise what was read (a "check" step, no tool), then propose rewrites one at a time.
- `config/routes.rb`: add `post :accept, :reject, on: :member` to chats.
- `index.html.erb`: the import card holds a multipart form with a PDF input and a select of `PublicApi.list(current_user)`.
- `show.html.erb` also passes `data-proposals`. `components/coach/ProposalCard.jsx` shows before/after with Accept/Reject buttons that POST and then remove the card.
- `packs/coach/package.yml`: add `packs/imports` (for `CvPdfImportService` and `LinkedinPdfParserService`).
- Locales: `coach.import.{pdf,word_note,pick_seera,review_seera,too_big,not_pdf}`, `coach.proposal.{accept,reject,before,after}`.

**Units:** (A) migration, public_api.rb, extract.rb, draft.rb schema. (B) controller, routes, job, tool, agent, views (depends on A). (C) frontend.

**Tests**
- `test/services/coach/extract_test.rb`: stub `RubyLLM::Chat.any_instance.stubs(:ask).returns(stub(parsed: {...}))`. Valid sections are kept and an invalid entry is dropped.
- `test/jobs/coach/turn_job_test.rb`: import chat with an empty draft → `Coach::Extract` is called once and a `draft` broadcast is sent; a non-empty draft → not called.
- `test/controllers/coach/chats_controller_test.rb`:
  - The PDF upload (`fixture_file_upload` of a tiny `test/fixtures/files/cv.pdf` with `CvPdfImportService.any_instance.stubs(:parse).returns(text: "...", language: "en")`; no PDF fixture exists today) creates an import chat whose first message holds the text and enqueues the job.
  - A non-PDF upload returns 422.
  - `resume_id` of the user's own resume puts that resume's content into the draft; another user's `resume_id` returns 404.
  - `accept` applies the change and removes the proposal; `reject` only removes it; another user's chat returns 404.
- `test/services/coach/tools/propose_rewrite_test.rb`: stores and broadcasts; a bad index returns an error.
- `test/services/resume_builder/public_api_test.rb`: `list` returns only that user's resumes, newest first.

**Verify:** upload a real PDF (one EN, one AR). The preview fills in, the agent summarises, and accepting a proposal updates the preview.

---

## PR 5: Jev judge

**Goal:** The coach picks what to work on next and scores the CV with Jev, and falls back to Haiku when Jev is unavailable.

**Files**
- `config/initializers/ruby_llm.rb`: `config.typesafe_api_key = ENV["JEV_API_KEY"]`.
- `packs/coach/app/services/coach/judge.rb`: `module Coach::Judge`.
  - `next_step(draft) -> String` (one of `Coach::Draft::SECTIONS`).
  - `review(draft) -> Hash{section => Float 0..1}`.
  - `sanitize(draft)`: `draft.except(*%w[complete_name email phone_number city country])`, rendered as text section by section. Only this goes out.
  - Questions: `next_step: { type: :choice, instructions:, options: SECTIONS.index_with { desc } }`, and one `"#{s}": { type: :score, levels: %w[missing weak ok strong] }` per section.
  - It calls `RubyLLM.judge(text, questions:, model: "jev-latest", provider: :typesafe)` if `RubyLLM.config.typesafe_api_key.present?`.
  - `rescue RubyLLM::Error, Faraday::Error` → `fallback`, the same questions through Haiku `with_schema` (`{next_step: enum, scores: {section: number}}`).
- `packs/coach/app/services/coach/tools/next_step.rb` and `review_cv.rb`: no params, each returns the Judge result. `agent.rb` TOOLS += both. The prompt says to call next_step when unsure what to ask, and review_cv before finishing.
- `.kamal/secrets`: `JEV_API_KEY=$JEV_API_KEY`. `config/deploy.yml` `env.secret`: `- JEV_API_KEY`. The user adds the repo secret; the plan never touches real values.

**Units:** one engineer; the change is small.

**Tests**
- `test/services/coach/judge_test.rb`:
  - `RubyLLM.expects(:judge).with { |input, **| !input.include?(email) && !input.include?(phone) && !input.include?(name) }.returns(judgment_stub)` (key set via `RubyLLM.config.stubs(:typesafe_api_key).returns("k")`).
  - No key → `RubyLLM.expects(:judge).never` and the Haiku chat stub is used.
  - `RubyLLM.judge` raising `RubyLLM::ServerError` → fallback result.
  - `next_step` is always in SECTIONS.
- `test/services/coach/tools/review_cv_test.rb`: returns a Hash of section scores (Judge stubbed).

**Verify:** `bin/kamal secrets print` lists JEV_API_KEY (locally, with a dummy env value). The full suite passes with no `JEV_API_KEY`.

---

## PR 6: Finish

**Goal:** "Send to Seera" makes a real resume. The header shows an "AI Coach" link to testers. The coach caps each user at 60 messages a day.

**Files**
- `chats_controller.rb`:
  - `send_to_seera`: `resume = ResumeBuilder::PublicApi.create_from_draft(current_user, @chat.draft)`, then `redirect_to resume_path(resume)`. A blank draft redirects back with the alert `t("coach.send.empty")`. This is a user action, not an LLM tool.
  - `message`: if `Coach.daily_count(current_user) >= Coach::DAILY_LIMIT`, it renders `{ error: t("coach.daily_cap") }`, status 429, and enqueues no job.
- `coach.rb`: `DAILY_LIMIT = 60` and `daily_count(user) = Coach::Message.joins(:chat).where(role: "user", coach_chats: { user_id: user.id }, created_at: Time.current.all_day).count`. No new column.
- `config/routes.rb`: `post :send_to_seera, on: :member`.
- `show.html.erb`: a "Send to Seera" `button_to` (`sr-btn sr-primary`). `CoachChat.jsx` shows the 429 `error` text inline.
- `app/views/shared/_site_header.html.erb`: after line 17 (desktop) and line 57 (mobile), inside the existing `user_signed_in?` blocks, add `<% if Coach.enabled_for?(current_user) %>` with `link_to t('nav.coach'), coach_root_path`, using the same classes as the `my_cv` link next to it. The root pack does not enforce deps, so this is fine for Packwerk.
- Locales: `nav.coach` ("AI Coach" / "المدرب الذكي"), `coach.send.{button,empty}`, `coach.daily_cap`.

**Units:** (A) controller, coach.rb, routes, show view. (B) header partial and nav locales.

**Tests**
- `test/controllers/coach/chats_controller_test.rb`:
  - `send_to_seera` creates one Resume with `source: "coach"` and redirects to it. Stub `Resume.any_instance.stubs(:queue_pdf_generation)` as in `public_api_test.rb`.
  - Another user's chat → 404 and no resume.
  - Empty draft → no resume.
  - Cap: create 60 user messages today, then POST → 429 and `assert_no_enqueued_jobs`. Messages from yesterday (`travel_to`) don't count.
- `test/controllers/home_controller_test.rb`: tester signed in → `assert_select "a[href='/coach']", 2`. Not a tester → `count: 0`.

**Verify:** a manual end-to-end run on each path ending in Send. The new resume opens in the builder and its PDF renders.

---

## Risks
- **Websockets in prod:** Thruster (`Dockerfile:88`) and kamal-proxy must pass `Upgrade`. Same-origin check behind TLS termination. The solid_cable `cable` DB must exist; `db:prepare` creates it, as it does for solid_cache. Check with a tester account right after deploy: devtools shows `/cable` 101, and Sentry is clean.
- **Broadcast volume:** every chunk is one solid_cable insert, with 1-day retention. Fine for testers. If it grows, buffer chunks for about 100ms in TurnJob.
- **Sidekiq worker** must reach the cable DB. It uses the same DB host, so check its logs on the first turn.
- **Concurrent turns:** the UI blocks input while a turn runs. A second tab could still race, which is accepted for testers.
- **Draft drift:** `PublicApi::REQUIRED` copies ResumeDraftSync's literals. The PR3 round-trip test guards this.
- **Dev:** streaming needs Redis and a running `sidekiq -q coach`; note this in the PR2 description.
- **Bedrock model access:** Sonnet 4.6 must be enabled in the AWS account. `COACH_MODEL` overrides it without a deploy change.
