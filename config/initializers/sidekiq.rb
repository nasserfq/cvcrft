# Sidekiq configuration
# Disable strict argument checking to allow HashWithIndifferentAccess
Sidekiq.strict_args!(false)

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Configure logging
  config.logger.level = Logger::INFO

  # The one place Sidekiq's thread count is set. config/sidekiq.yml has no
  # :concurrency on purpose: this block runs after the CLI reads that file, so
  # a value there was always overridden. config/database.yml sizes the DB pool
  # from the same SIDEKIQ_CONCURRENCY (default 5).
  config.concurrency = Integer(ENV.fetch("SIDEKIQ_CONCURRENCY", 5))

  # A job that ran out of retries (or was killed at once) lands in the Dead
  # set. Tell Sentry, so its new-issue email says so.
  config.death_handlers << ->(job, exception) { DeadJobReporter.call(job, exception) }
end

# Recurring jobs (sidekiq-cron). The gem loads config/schedule.yml in its own
# configure_server startup hook, so only Sidekiq server processes touch the
# schedule; web/console boots never talk to Redis for it. load_from_hash!
# there also removes jobs that were dropped from the file. Disabled in tests
# so nothing is ever scheduled from the test suite.
Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = Rails.root.join("config/schedule.yml").to_s
  config.enabled = !Rails.env.test?
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

# Configure Sidekiq web interface (optional)
if defined?(Sidekiq::Web)
  Sidekiq::Web.set :sessions, false
  Sidekiq::Web.set :protection, false
end
