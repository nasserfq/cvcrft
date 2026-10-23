require Rails.root.join("packs/accounts/lib/social_auth").to_s

# OmniAuth 2 only starts a sign-in on POST; omniauth-rails_csrf_protection
# checks the Rails authenticity token on it.
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.logger = Rails.logger

# Devise clears OmniAuth's path prefix and sets it again when the routes are
# drawn. Routes load lazily in development and test, so the first sign-in POST
# after boot would miss the strategy and 404. Set Devise's own prefix up front
# (devise_for checks that the two match). Not the app's /auth/* routes.
require "devise/omniauth"
OmniAuth.config.path_prefix = "/users/auth"

# The login form's PDPL consent and return_to ride through the provider round
# trip in the session; Users::OmniauthCallbacksController reads and clears them.
OmniAuth.config.before_request_phase = lambda do |env|
  request = Rack::Request.new(env)
  session = env["rack.session"]
  session["social_privacy_consent"] = request.params["privacy_consent"] == "1"
  session["social_return_to"] = request.params["return_to"].presence
end
