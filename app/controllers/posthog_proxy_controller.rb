# frozen_string_literal: true

# PostHog Reverse Proxy Controller
# Routes analytics requests through your domain to avoid ad blockers
# https://posthog.com/docs/advanced/proxy/nextjs#optional-set-up-proxy
class PosthogProxyController < ActionController::Base
  skip_before_action :verify_authenticity_token
  before_action :set_cors_headers

  POSTHOG_HOST = ENV.fetch("VITE_PUBLIC_POSTHOG_HOST", "https://us.i.posthog.com")
  POSTHOG_ASSETS_HOST = POSTHOG_HOST.gsub(".i.posthog.com", "-assets.i.posthog.com")

  # Handle CORS preflight requests
  def options
    head :ok
  end

  # Proxy ingest requests (events, identify, etc.)
  def ingest
    proxy_to_posthog(POSTHOG_HOST)
  end

  # Proxy static assets (JS files)
  def static
    proxy_to_posthog(POSTHOG_ASSETS_HOST)
  end

  # Proxy decide endpoint (feature flags, etc.)
  def decide
    proxy_to_posthog(POSTHOG_HOST)
  end

  private

  def set_cors_headers
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
    response.headers["Access-Control-Max-Age"] = "86400"
  end

  def proxy_to_posthog(host)
    uri = URI.parse("#{host}#{posthog_path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = 30
    http.open_timeout = 10

    # Build the request
    klass = request_class_for(request.method)
    posthog_request = klass.new(uri.request_uri)

    # Forward headers
    forward_headers(posthog_request)

    # Forward body for POST/PUT requests
    if request.body.present? && %w[POST PUT PATCH].include?(request.method)
      posthog_request.body = request.body.read
    end

    # Make the request
    response = http.request(posthog_request)

    # Return the response
    render body: response.body,
           status: response.code.to_i,
           content_type: response["Content-Type"]
  rescue StandardError => e
    Rails.logger.error("[PostHog Proxy] Error: #{e.message}")
    head :bad_gateway
  end

  def posthog_path
    # Remove the /ingest prefix and pass the rest
    path = request.fullpath
    path = path.sub(%r{^/ingest}, "")
    path = path.sub(%r{^/ph-static}, "/static")
    path.presence || "/"
  end

  def request_class_for(method)
    case method.upcase
    when "GET" then Net::HTTP::Get
    when "POST" then Net::HTTP::Post
    when "PUT" then Net::HTTP::Put
    when "PATCH" then Net::HTTP::Patch
    when "DELETE" then Net::HTTP::Delete
    when "OPTIONS" then Net::HTTP::Options
    else Net::HTTP::Get
    end
  end

  def forward_headers(posthog_request)
    # Forward relevant headers
    %w[Content-Type Accept Accept-Encoding User-Agent].each do |header|
      value = request.headers[header]
      posthog_request[header] = value if value.present?
    end

    # Forward the original IP for geolocation
    posthog_request["X-Forwarded-For"] = request.remote_ip
  end
end
