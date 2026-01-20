# PostHog Analytics Configuration
# https://posthog.com/docs/libraries/ruby

require 'posthog'

POSTHOG = PostHog::Client.new({
  api_key: Rails.application.credentials.dig(:posthog, :api_key) || ENV["POSTHOG_API_KEY"] || "phc_hbgIlm0QjZDuhGEO7YYg2tuAQcMnLDsafnm8A0Dw5S6",
  host: "https://us.i.posthog.com",
  on_error: Proc.new { |status, msg| Rails.logger.error("[PostHog] Error: #{status} - #{msg}") }
})

# Shutdown hook to flush events before app exits
at_exit { POSTHOG.shutdown }
