# PostHog Analytics Configuration
# https://posthog.com/docs/libraries/ruby-on-rails

# Core PostHog client initialization
PostHog.init do |config|
  # Required: Your PostHog API key
  config.api_key = ENV["POSTHOG_API_KEY"] || Rails.application.credentials.dig(:posthog, :api_key) || "phc_hbgIlm0QjZDuhGEO7YYg2tuAQcMnLDsafnm8A0Dw5S6"

  # Your PostHog instance URL
  config.host = "https://us.i.posthog.com"

  # Error callback to detect misconfiguration
  config.on_error = proc { |status, msg|
    Rails.logger.error("[PostHog] Error: #{msg} (status: #{status})")
  }

  # Test mode - don't send events in test environment
  config.test_mode = Rails.env.test?
end

# Rails-specific configuration
PostHog::Rails.configure do |config|
  # Enable automatic exception capture
  config.auto_capture_exceptions = true

  # Report exceptions Rails rescues
  config.report_rescued_exceptions = true

  # Instrument ActiveJob background jobs
  config.auto_instrument_active_job = true

  # No user info in exceptions (PDPL): exceptions are not gated on analytics consent
  config.capture_user_context = false

  # Method to get current user in controllers
  config.current_user_method = :current_user
end
