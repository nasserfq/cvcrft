# Sentry: error monitoring, performance tracing and logs.
# https://docs.sentry.io/platforms/ruby/guides/rails/
#
# Off unless SENTRY_DSN is set, so dev, test and deploys without the DSN
# behave exactly as before.
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"].presence
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # PDPL: never attach user IPs, cookies or user details to events.
  config.send_default_pii = false

  # Tag every event with the deployed git SHA (Kamal sets KAMAL_VERSION) so
  # Sentry can compare speed before and after each Deploy.
  config.release = ENV["SENTRY_RELEASE"].presence || ENV["KAMAL_VERSION"].presence

  # Performance: trace every request and job, minus health checks and load tests.
  config.traces_sampler = ->(context) { SentryTracesSampler.call(context) }

  # Logs: send Rails.logger warnings and errors, plus one structured log per
  # request (path, status, duration).
  config.enabled_patches << :logger
  config.std_lib_logger_filter = ->(_logger, _message, level) { %i[warn error fatal].include?(level) }
  config.rails.structured_logging.enabled = true
  config.rails.structured_logging.subscribers = {
    action_controller: Sentry::Rails::LogSubscribers::ActionControllerSubscriber
  }
end
