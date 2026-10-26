# Be sure to restart your server when you modify this file.

# Enforced Content-Security-Policy for every response.
# https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Pages carry many inline <script> and <style> blocks, so script-src and
# style-src allow 'unsafe-inline'. No nonce generator: a nonce in script-src
# makes browsers ignore 'unsafe-inline' and would block those blocks.
# The value is in the host lists: only the origins below can run scripts,
# receive fetches, be framed, or receive a form post.
#
# Adding a third-party script, API, font or OAuth provider? Add its origin here
# and to test/integration/content_security_policy_test.rb.

origin_of = lambda do |url|
  uri = URI.parse(url.to_s)
  "#{uri.scheme}://#{uri.host}#{":#{uri.port}" unless uri.port == uri.default_port}" if uri.host
rescue URI::InvalidURIError
  nil
end

# PostHog's inline loader (app/views/shared/_posthog.html.erb) talks to the API
# host and loads its scripts from the matching -assets host. The React client
# goes through the /ingest proxy, which is 'self'.
posthog_api = origin_of.call(ENV.fetch("VITE_PUBLIC_POSTHOG_HOST", "https://us.i.posthog.com"))
posthog_assets = posthog_api&.sub(".i.posthog.com", "-assets.i.posthog.com")
posthog = [ posthog_api, posthog_assets ].compact.uniq

# Browser Sentry sends events to the DSN's ingest host (production only).
sentry = [ origin_of.call(ENV["SENTRY_DSN"]) ].compact

# Cloudflare Web Analytics, injected into every page by the Cloudflare proxy:
# the beacon script, and the endpoint it reports to.
cloudflare_beacon = "https://static.cloudflareinsights.com"
cloudflare_rum = "https://cloudflareinsights.com"

google_fonts_css = "https://fonts.googleapis.com"
google_fonts_files = "https://fonts.gstatic.com"

# Sign-in buttons POST to /users/auth/<provider>, which redirects to the
# provider; browsers check form-action on that redirect. Buying credits POSTs
# to /credits/purchase, which redirects to Moyasar's hosted invoice page.
oauth_providers = %w[https://accounts.google.com https://appleid.apple.com https://www.linkedin.com]
moyasar = %w[https://checkout.moyasar.com https://*.moyasar.com]

# /cv_generations/new loads React and Babel from unpkg and compiles its JSX in
# the browser. Babel runs the result as an inline script, so no 'unsafe-eval'.
# Only that page may load from unpkg. Runs on the controller (or the request).
unpkg_page = lambda do
  respond_to?(:controller_path) && controller_path == "cv_generations" && action_name == "new" ? [ "https://unpkg.com" ] : []
end

dev_scripts = []
dev_connects = []
if Rails.env.development?
  # Vite dev server (bin/vite dev).
  vite = ViteRuby.config.host_with_port
  dev_scripts = [ "http://#{vite}" ]
  dev_connects = [ "http://#{vite}", "ws://#{vite}" ]
end

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self, :unsafe_inline, *posthog, cloudflare_beacon, *dev_scripts, unpkg_page
    policy.style_src       :self, :unsafe_inline, google_fonts_css
    policy.font_src        :self, :data, google_fonts_files
    policy.img_src         :self, :data, :blob, :https
    policy.connect_src     :self, *posthog, *sentry, cloudflare_rum, *dev_connects
    policy.worker_src      :self, :blob
    policy.frame_src       :self, :blob
    policy.object_src      :none
    policy.base_uri        :self
    policy.frame_ancestors :self
    policy.form_action     :self, *oauth_providers, *moyasar
  end

  config.content_security_policy_nonce_generator = nil
end
