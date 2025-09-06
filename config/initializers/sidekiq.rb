# Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Configure logging
  config.logger.level = Logger::INFO
  
  # Configure concurrency
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
  
  # Configure retry (retry_interval is not available in Sidekiq 8.0.4)
  # config.retry_interval = 60
  
  # Configure memory monitoring (memory_threshold is not available in Sidekiq 8.0.4)
  # config.memory_threshold = 1_000_000_000 # 1GB
  
  # Configure dead job handling (death_handlers is not available in Sidekiq 8.0.4)
  # config.death_handlers << ->(job, ex) do
  #   Rails.logger.error "Job #{job['class']} failed with error: #{ex.message}"
  # end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure Sidekiq web interface (optional)
if defined?(Sidekiq::Web)
  Sidekiq::Web.set :sessions, false
  Sidekiq::Web.set :protection, false
end 