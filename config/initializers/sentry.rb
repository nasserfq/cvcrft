# Sentry: error monitoring, performance tracing and logs.
# https://docs.sentry.io/platforms/ruby/guides/rails/
#
# Off unless SENTRY_DSN is set, so dev, test and deploys without the DSN
# behave exactly as before.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"].presence
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Performance: trace 20% of requests and jobs.
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.2").to_f

  # Logs: send Rails.logger warnings and errors, plus one structured log per
  # request (path, status, duration).
  config.enabled_patches << :logger
  config.std_lib_logger_filter = ->(_logger, _message, level) { %i[warn error fatal].include?(level) }
  config.rails.structured_logging.enabled = true
  config.rails.structured_logging.subscribers = {
    action_controller: Sentry::Rails::LogSubscribers::ActionControllerSubscriber
  }
end
