require "ipaddr"

# kamal-proxy terminates TLS and rewrites X-Forwarded-For, so Rails sees the
# Cloudflare edge as the client and every visitor behind one edge shares a
# rate limit. When the hop Rails picked is a Cloudflare address, take the
# visitor's IP from CF-Connecting-IP instead. A request that reaches the
# server directly cannot come from a Cloudflare address, so it can't fake it.
# Ranges: https://www.cloudflare.com/ips/
class CloudflareRemoteIp
  RANGES = %w[
    173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22
    141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20
    197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
    104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32
    2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
  ].map { |range| IPAddr.new(range) }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    visitor = visitor_ip(env)
    env["action_dispatch.remote_ip"] = visitor if visitor
    @app.call(env)
  end

  private

  def visitor_ip(env)
    header = env["HTTP_CF_CONNECTING_IP"].to_s.strip
    return if header.empty?
    return unless cloudflare?(env["action_dispatch.remote_ip"].to_s)

    IPAddr.new(header).to_s
  rescue IPAddr::InvalidAddressError
    nil
  end

  def cloudflare?(ip)
    address = IPAddr.new(ip)
    RANGES.any? { |range| range.include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end
end
