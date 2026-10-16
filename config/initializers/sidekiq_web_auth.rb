# HTTP Basic auth for the Sidekiq dashboard, using the admin panel's
# credentials (see Admin::ApplicationController). ADMIN_PASSWORD has no
# fallback: when it is unset the dashboard gets an unguessable random password
# for the life of the process, so a misconfiguration locks it rather than
# leaving it open.
class SidekiqWebAuth
  REALM = "Sidekiq".freeze

  def self.from_env
    new(
      username: ENV.fetch("ADMIN_USERNAME", "admin"),
      password: ENV.fetch("ADMIN_PASSWORD") { SecureRandom.hex(32) }
    )
  end

  def initialize(username:, password:)
    @username = username.to_s
    @password = password.to_s
  end

  # Compares both fields in constant time, and always both, so timing does not
  # reveal which one was wrong.
  def valid?(username, password)
    username_ok = ActiveSupport::SecurityUtils.secure_compare(username.to_s, @username)
    password_ok = ActiveSupport::SecurityUtils.secure_compare(password.to_s, @password)
    username_ok && password_ok
  end

  # Returns +app+ behind HTTP Basic auth checked by #valid?.
  def wrap(app)
    auth = self
    Rack::Auth::Basic.new(app, REALM) { |username, password| auth.valid?(username, password) }
  end
end
