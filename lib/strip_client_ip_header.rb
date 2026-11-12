# Our proxies (Cloudflare, kamal-proxy) never set Client-IP, so any value is
# whatever the caller typed. When it disagreed with X-Forwarded-For, Rails
# raised IpSpoofAttackError and served a 500 (Sentry RUBY-RAILS-7). Dropping
# it keeps the spoofing check on and the IP coming from X-Forwarded-For.
class StripClientIpHeader
  def initialize(app)
    @app = app
  end

  def call(env)
    env.delete("HTTP_CLIENT_IP")
    @app.call(env)
  end
end
