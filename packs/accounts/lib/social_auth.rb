require "base64"

# Which social sign-in providers are on, and how to configure them. The Devise
# initializer, the User model and the login view all ask this one object, so a
# provider with a missing secret has no middleware, no route and no button.
# It lives outside the autoload paths because initializers require it.
module SocialAuth
  PROVIDERS = {
    google_oauth2: { short: "google",   env: %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET] },
    apple:         { short: "apple",    env: %w[APPLE_CLIENT_ID APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY] },
    linkedin:      { short: "linkedin", env: %w[LINKEDIN_CLIENT_ID LINKEDIN_CLIENT_SECRET] }
  }.freeze

  # Apple posts its answer cross-site (response_mode=form_post), so its
  # redirect_uri is our bounce endpoint, built per request from the host.
  APPLE_SETUP = lambda do |env|
    env["omniauth.strategy"].options[:redirect_uri] = "#{Rack::Request.new(env).base_url}/auth/apple/form_post"
  end

  module_function

  # Pure: which providers have every ENV var non-blank.
  def configured(env = ENV)
    PROVIDERS.select { |_, provider| provider[:env].all? { |key| env[key].to_s.strip.present? } }.keys
  end

  # Boot-time list. Test env: all on, so routes exist for OmniAuth test_mode.
  def providers
    @providers ||= Rails.env.test? ? PROVIDERS.keys : configured
  end

  def enabled?(name)
    providers.include?(name.to_sym)
  end

  def short_name(name)
    PROVIDERS.fetch(name.to_sym)[:short]
  end

  # Repo secrets drop multi-line values, so the .p8 is stored base64-encoded.
  def apple_private_key(raw = ENV["APPLE_PRIVATE_KEY"].to_s)
    raw.include?("BEGIN") ? raw.gsub("\\n", "\n") : Base64.decode64(raw)
  end

  # [id, secret, options] for config.omniauth. The test env gets placeholders
  # when the vars are blank, so nothing is decoded or read.
  def credentials(name, env = ENV)
    placeholder = Rails.env.test? && !configured(env).include?(name.to_sym)
    value = ->(key) { placeholder ? "test" : env[key] }

    case name.to_sym
    when :google_oauth2
      [ value.("GOOGLE_CLIENT_ID"), value.("GOOGLE_CLIENT_SECRET"), { scope: "email,profile", prompt: "select_account" } ]
    when :linkedin
      [ value.("LINKEDIN_CLIENT_ID"), value.("LINKEDIN_CLIENT_SECRET"), { scope: "openid profile email" } ]
    when :apple
      pem = placeholder ? "" : apple_private_key(env["APPLE_PRIVATE_KEY"].to_s)
      [ value.("APPLE_CLIENT_ID"), "",
        { scope: "email name", team_id: value.("APPLE_TEAM_ID"), key_id: value.("APPLE_KEY_ID"), pem:, setup: APPLE_SETUP } ]
    else
      raise ArgumentError, "unknown social provider: #{name}"
    end
  end
end
