# Social sign-in: Google, Apple, LinkedIn

Date: 2026-10-20. Pack: `accounts`. One work unit, one `software-engineer`.

## 1. Goal

On `/login` the user sees, inside the existing Seera glass card, one PDPL consent checkbox, then
"Continue with Google", "Continue with Apple" and "Continue with LinkedIn" buttons (Arabic:
"المتابعة باستخدام Google" and so on), then an "or continue with email" divider and the current
email-code form, which works exactly as today. A provider button only appears when that provider's
secrets are set; with no secrets the page looks like it does today and nothing fails at boot or deploy.

Clicking a button without ticking the consent box shows the same browser validation message as the
email form. With consent, the user signs in at the provider and lands on `return_to` or
`/resumes/new`, signed in. New accounts record `privacy_accepted_at` and `privacy_policy_version`
the same way the OTP path does. A returning Apple user (no email sent after the first login) is
found by provider id. An existing email account is linked only when the provider says the email
is verified. "Download my data" includes the linked sign-in accounts, and deleting the account
deletes them.

## 2. Approach

**Devise `:omniauthable` driven by one config object.** `SocialAuth` (plain Ruby, in
`packs/accounts/lib/social_auth.rb`) knows the three providers, which ENV vars each needs and how
to build its options. The Devise initializer, the `User` model (`omniauth_providers:`) and the login
view all ask it, so "secret missing" means one thing everywhere: no middleware, no route, no button.
It is loaded with an explicit `require` from the initializer because initializers must not touch
autoloaded (reloadable) constants. That is why it lives in `packs/accounts/lib/`, outside the
autoload paths, and not in `packs/accounts/app/`. In the test environment it reports all three
providers on with placeholder credentials, so routes exist and `OmniAuth.config.test_mode` can
drive them.

**Consent is carried through the provider round trip in the session.** The buttons are POST forms
(OmniAuth 2 only allows POST for the request phase, and `omniauth-rails_csrf_protection` checks the
Rails token). Each form sends `privacy_consent` and `return_to`. An
`OmniAuth.config.before_request_phase` hook copies them into `session["social_privacy_consent"]`
and `session["social_return_to"]`. The callback reads and deletes them. The server enforces
consent on its own, so a no-JS user or a forged POST cannot create an account without it. The JS
is only the friendly front end.

**Apple's `form_post` is bounced to a same-site GET.** Apple requires `response_mode=form_post`
when it asks for name/email. That is a cross-site POST, so the `SameSite=Lax` session cookie is
not sent and OmniAuth's `state` check fails. Apple's `redirect_uri` is therefore a plain Rails
endpoint, `POST /auth/apple/form_post` (no CSRF, no auth). It answers `303` to
`/users/auth/apple/callback?code=…&state=…&id_token=…&user=…`. The browser then does a top-level
GET, which carries the Lax cookie, and OmniAuth runs its normal callback. The strategy's
`redirect_uri` option is set per request in a `setup` lambda from `request.base_url`. Production
has `assume_ssl`, so this gives `https://cvcrft.com/auth/apple/form_post`, and the authorize and
token-exchange calls use the same URI. No new host config is needed, and dev and test work too.
This beats the obvious alternative, `same_site: :none` on the session cookie, which would weaken
CSRF protection for the whole app to fix one callback.

**One service decides who the user is.** `SocialSignIn.call(auth, consent:, locale:)` returns a
small result (`user`, `error`, `created`). It finds the user by identity (provider + uid), then by
verified email, and otherwise creates a new user. It does no HTTP and no session work, so the rules
are unit-testable. The callback controller only maps the result to sign-in, a flash message and a
redirect.

## 3. Work unit (single engineer, do the steps in order)

Owner: one `software-engineer`. No other unit edits these files.

### Step 1. Gems
- `Gemfile`: add `omniauth` (`~> 2.1`), `omniauth-rails_csrf_protection`, `omniauth-google-oauth2`,
  `omniauth-apple`, `omniauth-linkedin-openid`. Run `bundle install` and commit `Gemfile.lock`.
- Before going on, open the installed `omniauth` source (`bundle exec gem contents omniauth`, file
  `lib/omniauth/strategy.rb`) and confirm that `mock_request_call` invokes
  `OmniAuth.config.before_request_phase`. The integration tests rely on it. If it does not, the
  tests set the session keys directly instead (see Step 11).

### Step 2. `packs/accounts/lib/social_auth.rb` (new)
```ruby
module SocialAuth
  PROVIDERS = {
    google_oauth2: { short: "google",   env: %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET] },
    apple:         { short: "apple",    env: %w[APPLE_CLIENT_ID APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY] },
    linkedin:      { short: "linkedin", env: %w[LINKEDIN_CLIENT_ID LINKEDIN_CLIENT_SECRET] }
  }.freeze

  module_function

  # Pure: which providers have every ENV var non-blank.
  def configured(env = ENV) = PROVIDERS.select { |_, p| p[:env].all? { |k| env[k].to_s.strip.present? } }.keys

  # Boot-time list. Test env: all on, so routes exist for OmniAuth test_mode.
  def providers = @providers ||= (Rails.env.test? ? PROVIDERS.keys : configured)
  def enabled?(name) = providers.include?(name.to_sym)
  def short_name(name) = PROVIDERS.fetch(name.to_sym)[:short]

  # Repo secrets drop multi-line values, so the .p8 is stored base64-encoded.
  def apple_private_key(raw = ENV["APPLE_PRIVATE_KEY"].to_s)
    raw.include?("BEGIN") ? raw.gsub("\\n", "\n") : Base64.decode64(raw)
  end

  def credentials(name, env = ENV) # [id, secret, options] for config.omniauth
    ...
  end
end
```
`credentials` returns:
- google_oauth2: `[GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, { scope: "email,profile", prompt: "select_account" }]`
- linkedin: `[LINKEDIN_CLIENT_ID, LINKEDIN_CLIENT_SECRET, { scope: "openid profile email" }]`
- apple: `[APPLE_CLIENT_ID, "", { scope: "email name", team_id:, key_id:, pem: apple_private_key, setup: APPLE_SETUP }]`,
  where
  ```ruby
  APPLE_SETUP = ->(env) {
    env["omniauth.strategy"].options[:redirect_uri] = "#{Rack::Request.new(env).base_url}/auth/apple/form_post"
  }
  ```
- In the test env, when the ENV vars are blank, use `"test"` placeholders (and an empty pem) so
  nothing is decoded or read.

Keep it to about 60 lines. Add `require "base64"` at the top.

### Step 3. `config/initializers/devise.rb`
Replace the commented `config.omniauth :github` line (~274) with:
```ruby
require Rails.root.join("packs/accounts/lib/social_auth").to_s
SocialAuth.providers.each { |name| id, secret, opts = SocialAuth.credentials(name); config.omniauth name, id, secret, **opts }
```
Put the `require` at the top of the file, outside `Devise.setup`. Do **not** set
`omniauth_path_prefix`: Devise's `/users/auth` keeps OmniAuth off the app's own `/auth/*` routes.

### Step 4. `config/initializers/omniauth.rb` (new)
```ruby
require Rails.root.join("packs/accounts/lib/social_auth").to_s
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger
OmniAuth.config.before_request_phase = lambda do |env|
  request = Rack::Request.new(env)
  session = env["rack.session"]
  session["social_privacy_consent"] = request.params["privacy_consent"] == "1"
  session["social_return_to"] = request.params["return_to"].presence
end
```
`config/initializers/filter_parameter_logging.rb`: add `:state` and `/\Acode\z/` (`id_token` is
already covered by `:token`). These keep the Apple bounce's query string out of the logs.

### Step 5. Migration `db/migrate/20261020000100_create_user_identities.rb` (new) and `db/schema.rb`
```ruby
create_table :user_identities do |t|
  t.references :user, null: false, foreign_key: true
  t.string :provider, null: false
  t.string :uid, null: false
  t.string :email
  t.timestamps
end
add_index :user_identities, [ :provider, :uid ], unique: true
```
Run `bin/rails db:migrate` against the **local development database only**. Commit the regenerated
`db/schema.rb`.

### Step 6. Models
- `packs/accounts/app/models/user_identity.rb` (new): `belongs_to :user`, and validates `provider`
  (inclusion in `SocialAuth::PROVIDERS.keys.map(&:to_s)`) and `uid` (presence, uniqueness scoped
  to `provider`).
- `packs/accounts/app/models/user.rb`:
  - Add `:omniauthable, omniauth_providers: SocialAuth.providers` to the `devise` call.
  - Add `has_many :identities, class_name: "UserIdentity", dependent: :destroy`.
  - Add the method:
    ```ruby
    def record_privacy_consent!
      update_columns(privacy_accepted_at: Time.current, privacy_policy_version: PrivacyPolicy::VERSION)
    end
    ```
  - Update the stale comment that says ":omniauthable" is available.

### Step 7. `packs/accounts/app/services/social_sign_in.rb` (new)
```ruby
class SocialSignIn
  Result = Struct.new(:user, :error, :created, keyword_init: true)
  # errors: :no_email, :email_unverified, :consent_required, :invalid

  def self.call(auth, consent:, locale: I18n.locale) = new(auth, consent:, locale:).call

  def call
    identity = UserIdentity.find_by(provider: auth.provider.to_s, uid: auth.uid.to_s)
    return finish(identity.user) if identity
    return fail(:no_email) if email.blank?
    return fail(:email_unverified) unless email_verified?
    user = User.find_by("LOWER(email) = ?", email)
    return fail(:consent_required) if user.nil? && !consent
    created = user.nil?
    User.transaction do
      user ||= User.create!(email:, name: display_name, locale: locale_string, password: pw, password_confirmation: pw)
      user.identities.create!(provider: auth.provider.to_s, uid: auth.uid.to_s, email:)
    end
    finish(user, created:)
  rescue ActiveRecord::RecordNotUnique
    retry_once ... # a double-clicked callback: look the identity up again and finish with it, else :invalid
  rescue ActiveRecord::RecordInvalid
    fail(:invalid)
  end
end
```
Rules:
- `email` = `auth.info.email.to_s.strip.downcase`.
- `email_verified?`:
  - `apple` is always true. Apple only returns verified addresses, private relay included.
  - `google_oauth2` is true when `auth.extra.raw_info.email_verified` is `true` or `"true"`.
  - `linkedin` is true when `auth.extra.raw_info.email_verified` is `true` or `"true"`.
  - Anything else is false.
- `finish(user)`: if `consent`, call `user.record_privacy_consent!`. If the user has never consented
  (`privacy_accepted_at.nil?`) and `consent` is false, return `:consent_required` without signing in.
  This is the same rule as OTP, where no code is sent without consent.
- `display_name`: take the first candidate whose stripped length is between 2 and 100 from
  `[auth.info.name, [first_name, last_name].join(" "), email prefix]` (truncate long ones to 100).
  Fall back to `I18n.t("social_auth.default_name")`.
- `locale_string` = `I18n.locale.to_s` if it is `"ar"` or `"en"`, else `"ar"`.
- An unverified email never creates or links an account. Creating one would squat on someone
  else's address, and that person's OTP login would then land in the squatter's account.

### Step 8. Controllers and routes
- `packs/accounts/app/controllers/login_redirect.rb` (new module, at the controllers root so it
  avoids the pack `concerns/` load-path question): move `safe_return_to` here from
  `AuthController`, as a private method. Include the module in `AuthController` and in the
  callbacks controller.
- `packs/accounts/app/controllers/auth_controller.rb`: include `LoginRedirect`, delete its own
  `safe_return_to`, and change `record_privacy_consent(user)` to call `user.record_privacy_consent!`.
  The OTP behaviour must not change.
- `packs/accounts/app/controllers/users/omniauth_callbacks_controller.rb` (new):
  ```ruby
  class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
    include LoginRedirect
    def google_oauth2 = handle
    def apple = handle
    def linkedin = handle

    def failure
      redirect_to login_path(return_to: session.delete("social_return_to")), alert: t("social_auth.failed")
    end

    private

    def handle
      auth = request.env["omniauth.auth"]
      consent = session.delete("social_privacy_consent") == true
      return_to = session.delete("social_return_to")
      result = SocialSignIn.call(auth, consent:)
      return redirect_to(login_path(return_to:), alert: error_message(result.error)) if result.error
      sign_in(:user, result.user)
      identify_user(result.user)
      track_event("user_logged_in", { login_method: SocialAuth.short_name(auth.provider), new_user: result.created })
      redirect_to safe_return_to(return_to) || new_resume_path, notice: t("ux_i18n.auth.signed_in")
    end
  end
  ```
  `error_message` maps the errors to locale keys:
  - `:consent_required` maps to `pdpl_consent.required`, the same key the email path uses.
  - Every other error maps to `social_auth.errors.<error>`.

  Log the provider and the error symbol only, never the email.
- `packs/accounts/app/controllers/social_auth_controller.rb` (new):
  ```ruby
  class SocialAuthController < ApplicationController
    # Apple posts here cross-site (response_mode=form_post); no session cookie or CSRF token arrives.
    skip_forgery_protection only: :apple_form_post
    APPLE_PARAMS = %w[code state id_token user error].freeze
    def apple_form_post
      query = request.request_parameters.slice(*APPLE_PARAMS).to_query
      redirect_to "#{user_apple_omniauth_callback_path}?#{query}", status: :see_other
    end
  end
  ```
- `config/routes.rb`:
  - Line 16 becomes `devise_for :users, skip: [ ...same... ], controllers: { omniauth_callbacks: "users/omniauth_callbacks" }`.
    Do not add `:omniauth_callbacks` to `skip`.
  - Next to the auth routes (~:174), add
    `post "/auth/apple/form_post", to: "social_auth#apple_form_post", as: :apple_form_post`.
  - Clash check: the existing `/auth/*` routes are exact paths (`send_otp`, `verify_otp`,
    `logout`, `status`), and OmniAuth only intercepts `/users/auth/*`, so nothing overlaps. Confirm
    with `bin/rails routes -g auth`.

### Step 9. View `packs/accounts/app/views/auth/login.html.erb`
Inside `#email-step`, which stays hidden on the OTP step, the order becomes:
1. **Consent block.** Move the existing consent `<div>` out of the email `<form>` to the top of
   `#email-step`, unchanged except that the `<input>` gets `form="email-form"`. Give the email form
   `id="email-form"`. Native `required` validation and submission with the email form keep working
   through the HTML `form` attribute.
2. **Social buttons**, only when `SocialAuth.providers.any?`. Use
   `<div class="flex flex-col gap-3">` and loop over `SocialAuth::PROVIDERS.keys` with
   `SocialAuth.enabled?(p)`. Each button is a `button_to`:
   ```erb
   <%= button_to omniauth_authorize_path(:user, p), method: :post, data: { turbo: false, social_auth: true },
         form: { class: "w-full", "data-social-form": "" },
         params: { return_to: params[:return_to], privacy_consent: "0" },
         class: "sr-btn glass-soft w-full min-h-[44px] rounded-xl px-4 flex items-center justify-center gap-3 text-[15px] font-medium cursor-pointer",
         style: "color: #eef3ee" do %>
     <%= render "auth/social_logo", provider: p %>
     <span><%= t("social_auth.continue_with.#{SocialAuth.short_name(p)}") %></span>
   <% end %>
   ```
   `button_to` adds the authenticity token, which `omniauth-rails_csrf_protection` needs.
3. **Divider.** A flex row of two `h-px` lines (`background: rgba(238,243,238,0.12)`) around
   `t("social_auth.or_email")`, styled `text-sm` with `color: rgba(238,243,238,0.55)`. Only render
   it when buttons are shown. Use logical spacing only (`gap`, `ms-`/`me-`), never `ml`/`mr`, so it
   mirrors in RTL.
4. **The existing email form**, without the consent block.

- `packs/accounts/app/views/auth/_social_logo.html.erb` (new) holds the inline SVGs, 20px,
  `aria-hidden="true"`, `flex-none`:
  - Google: the four-colour "G" (#4285F4, #34A853, #FBBC05, #EA4335).
  - Apple: a white (`fill="#fff"`) apple glyph.
  - LinkedIn: an "in" mark with a `#0A66C2` rounded square and a white "in".

  Logos are not mirrored in RTL. The button text reads "المتابعة باستخدام Google" (brand names stay
  Latin).
- JS, appended inside the existing `<script>`. Leave the OTP code untouched:
  ```js
  document.querySelectorAll('form[data-social-form]').forEach(form => {
    form.addEventListener('submit', e => {
      const consent = document.getElementById('privacy_consent');
      if (consent && !consent.checked) { e.preventDefault(); consent.reportValidity(); consent.focus(); return; }
      form.querySelector('input[name="privacy_consent"]').value = '1';
    });
  });
  ```
  `reportValidity()` shows the same native "required" bubble the email path shows. Without JS the
  hidden value stays `"0"` and the server answers with the `pdpl_consent.required` flash for new
  users.
- Header copy: `auth.otp_instruction` talks only about email. Leave it. Changing it is out of scope.

### Step 10. Locales, export, docs, deploy config
- `config/locales/social_auth.en.yml` and `config/locales/social_auth.ar.yml` (new). Both files
  have the same keys:

  | Key | English | Arabic |
  |---|---|---|
  | `social_auth.continue_with.google` | Continue with Google | المتابعة باستخدام Google |
  | `social_auth.continue_with.apple` | Continue with Apple | المتابعة باستخدام Apple |
  | `social_auth.continue_with.linkedin` | Continue with LinkedIn | المتابعة باستخدام LinkedIn |
  | `social_auth.or_email` | Or continue with email | أو تابع باستخدام البريد الإلكتروني |
  | `social_auth.default_name` | Seera AI user | مستخدم Seera AI |
  | `social_auth.failed` | We couldn't sign you in with that account. Please try again or use your email. | تعذّر تسجيل دخولك بهذا الحساب. حاول مرة أخرى أو استخدم بريدك الإلكتروني. |
  | `social_auth.errors.no_email` | That account didn't share an email address. Please sign in with your email. | لم يشارك هذا الحساب بريدًا إلكترونيًا. يرجى تسجيل الدخول ببريدك الإلكتروني. |
  | `social_auth.errors.email_unverified` | That account's email isn't verified. Please sign in with your email code. | البريد الإلكتروني لهذا الحساب غير مُوثّق. يرجى تسجيل الدخول برمز البريد الإلكتروني. |
  | `social_auth.errors.invalid` | We couldn't create your account. Please sign in with your email. | تعذّر إنشاء حسابك. يرجى تسجيل الدخول ببريدك الإلكتروني. |

  Also add `devise.omniauth_callbacks.success` and `devise.omniauth_callbacks.failure` in both
  languages, so any Devise fallback is bilingual. Devise's English already has them, so the Arabic
  pair goes in `social_auth.ar.yml`.
- `packs/accounts/app/services/user_data_export.rb`: add the key
  `"identities" => user.identities.order(:id).map { |i| i.attributes.slice("provider", "uid", "email", "created_at") }`.
- `docs/pdpl.md`:
  - Add a row: "Name, email, provider account id from Google / Apple / LinkedIn sign-in | Sign-in
    | Consent (privacy policy at login) + contract | Google, Apple, LinkedIn (identity providers)
    | USA | Until the user deletes the account".
  - Note in the rights table that deletion also removes linked sign-in accounts.
  - Add the three DPAs/terms to the owner actions.
- `config/deploy.yml` `env.secret`: append these lines, each group with a one-line comment in the
  file's style ("Social sign-in (packs/accounts). Optional: a provider's button is hidden while its
  vars are empty."):
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`
  - `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`
- `.kamal/secrets`: add matching `NAME=$NAME` lines, grouped by provider, with short comments. For
  Apple: "APPLE_CLIENT_ID is the Services ID; APPLE_PRIVATE_KEY is the .p8 file base64-encoded on
  one line (`base64 -w0 AuthKey_XXXX.p8`), because multi-line repo secrets are dropped." Empty
  values are fine; `JEV_API_KEY` already relies on this.
- Do **not** touch `.github/workflows/*`, and do not add any secret values anywhere.

### Step 11. Tests (see section 5), then gates (see section 7).

## 4. Data

- There is one new table, `user_identities`, created by an additive migration. It changes no
  existing columns and needs no backfill. Old code ignores the table, so a rollback is
  `db:rollback` with no data loss for existing users.
- The foreign key and `dependent: :destroy` mean `ProfilesController#destroy` (`user.destroy!`
  inside its transaction) removes identities. No controller change is needed.
- Run migrations only against local development and test databases. Production migrates through
  the normal deploy.

## 5. Tests

- `test/services/social_auth_test.rb` (new):
  - `configured` returns only the providers whose vars are all non-blank. Pass hashes, never touch
    the real ENV.
  - `"   "` counts as missing.
  - `apple_private_key` decodes base64 and handles a literal `\n` PEM.
  - `short_name` works.
- `test/services/social_sign_in_test.rb` (new). Build auth hashes with
  `OmniAuth::AuthHash.new(provider:, uid:, info: {...}, extra: { raw_info: {...} })`. Cover:
  - A new Google user with consent creates a user, an identity, sets `privacy_accepted_at`, the
    current `privacy_policy_version`, and `created: true`.
  - A new user without consent gets `:consent_required`, and no `User` or `UserIdentity` is created.
  - A verified Google email that matches an existing user (different case) links it: one identity,
    no new user.
  - An unverified LinkedIn email returns `:email_unverified` whether or not a user with that email
    exists, and nothing is created.
  - A returning Apple user, matched by uid with no email in the hash, gets the same user back.
  - No email and no identity returns `:no_email`.
  - Name fallbacks: a 1-char name falls back to the email prefix, a blank one too, and a 300-char
    name is truncated to 100.
  - A user who never consented and arrives without consent gets `:consent_required`.
- `test/controllers/social_sign_in_controller_test.rb` (new, integration). In `setup` set
  `OmniAuth.config.test_mode = true`. In `teardown` set `test_mode = false` and clear `mock_auth`.
  Cover:
  - `post "/users/auth/google_oauth2", params: { privacy_consent: "1", return_to: "/resumes" }`,
    then `follow_redirect!`. Expect the user signed in (redirect to `/resumes`), a user and an
    identity created, and consent recorded.
  - The same without `privacy_consent`: redirect to `login_path` with flash
    `I18n.t("pdpl_consent.required", locale: :ar)` and no user.
  - `return_to: "//evil.com"` falls back to `new_resume_path`.
  - With `OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials`, the failure redirects
    to `login_path` with `social_auth.failed`.
  - `post "/auth/apple/form_post", params: { code: "c", state: "s", id_token: "t", user: '{"name":{}}', extra: "x" }`
    returns 303 with a `Location` of `/users/auth/apple/callback?...` that contains code, state,
    id_token and user but not `extra`. The request needs no CSRF token, so set
    `ActionController::Base.allow_forgery_protection = true` for this test and restore it after.
  - If Step 1 showed that `before_request_phase` does not run in mock mode, seed the session by
    adding a test-only branch, or stub it with mocha on `OmniAuth.config.before_request_phase`. Do
    not change production code for the test.
- `test/controllers/auth_controller_test.rb`: add three tests.
  - The login page renders the three buttons and one `privacy_consent` checkbox.
  - With `SocialAuth.stubs(:providers).returns([])` the page renders no social form and no divider.
  - The existing OTP tests still pass unchanged. They cover the `record_privacy_consent!` refactor.
- `test/services/user_data_export_test.rb`: add `identities` to the `expected` key list, and add a
  test that a created identity appears with provider, uid and email.
- `test/models/user_test.rb`: destroying a user destroys its identities.

## 6. Risks

| Risk | How to check |
|---|---|
| Boot or deploy breaks when a secret is empty | `SocialAuth.configured` treats blank as missing. Run `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner 'p SocialAuth.providers'` with no social ENV and expect `[]`. Expect `bin/rails routes -g auth` to show only `/users/auth/failure` and `/auth/apple/form_post` in dev without vars |
| Autoload error from referencing `SocialAuth` in initializers | It is required explicitly and lives outside the autoload paths. CI runs with `eager_load` on, so `bin/rails test` catches it |
| OTP login regressions (the view moved the consent box, `safe_return_to` moved, the consent refactor) | Existing `auth_controller_test.rb` stays green. Manual check: email path with the box unticked shows the native bubble, and ticked sends the code |
| Apple state check fails (Lax cookie) | The form_post bounce, covered by a test. After deploy, a manual Apple login on Safari and Chrome. The Services ID return URL must be exactly `https://cvcrft.com/auth/apple/form_post` |
| `redirect_uri` mismatch at Apple token exchange | Authorize and token use the same `options[:redirect_uri]` from the setup lambda, which depends on `assume_ssl` giving `https` |
| Codes and id_token in the query string | One-time and short-lived. Filtered from Rails logs (Step 4). The callback renders no HTML, so PostHog never sees the URL. The kamal-proxy access log may record it, which is accepted |
| Account takeover by email linking | Linking happens only on a verified email. An unverified email is refused outright |
| Apple private relay emails do not match existing accounts | This is expected: a new account is created. Mention it in the release note |
| Route clash with `/auth/*` | OmniAuth stays on `/users/auth`. Do not set `omniauth_path_prefix` |
| Devise failure path points at the skipped `sessions#new` | `failure` is overridden to `login_path` |
| Packwerk / brakeman | `bin/packwerk check` (accounts has `enforce_dependencies: false`). Brakeman may flag the redirect in `apple_form_post`: the path is fixed and only whitelisted params are appended. If flagged, add a reasoned entry to `config/brakeman.ignore` |
| Session cookie size | Two small keys, deleted in the callback |

## 7. Gates (all must pass before handing to `qa-tester`)

1. `bin/rails db:migrate` (dev) and `bin/rails db:test:prepare`. `db/schema.rb` gains only
   `user_identities`.
2. `bin/rails test test/services/social_auth_test.rb test/services/social_sign_in_test.rb test/controllers/social_sign_in_controller_test.rb test/controllers/auth_controller_test.rb test/services/user_data_export_test.rb test/models/user_test.rb`
3. `bin/rails test` (full suite) and `bin/rails test:system` if it runs locally.
4. `bin/rubocop`, `bin/brakeman --no-pager`, `bin/packwerk check`, `bin/importmap audit`.
5. Check the provider list without social ENV in dev: `bin/rails runner 'p SocialAuth.providers'`
   prints `[]`, and `/login` renders without buttons or divider.
6. Run `git diff --stat` and confirm:
   - no file under `.github/` changed;
   - no secret values were added;
   - every new user-facing string has both an `en` and an `ar` key (run
     `bin/rails runner` with an `I18n.t` check, or compare the key sets of the two
     `social_auth.*.yml` files).

## 8. Open for the owner (not blocking)

- The privacy page does not list processors by name. Should the page get a line on social sign-in
  data (and `PrivacyPolicy::VERSION` a bump)? That is a legal call, so this plan leaves it as is.
- Register the redirect URLs with each provider:
  - Google: `https://cvcrft.com/users/auth/google_oauth2/callback`
  - LinkedIn: `https://cvcrft.com/users/auth/linkedin/callback`
  - Apple: return URL `https://cvcrft.com/auth/apple/form_post`, and domain `cvcrft.com`
- The admin dashboard for identities is skipped. It is optional.
