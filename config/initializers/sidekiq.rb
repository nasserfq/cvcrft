# Sidekiq configuration
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # Configure logging
  config.logger.level = Logger::INFO
  
  # Configure concurrency
  config.concurrency = ENV.fetch('SIDEKIQ_CONCURRENCY', 5).to_i
  
  # Configure retry
  config.retry_interval = 60
  
  # Configure memory monitoring
  config.memory_threshold = 1_000_000_000 # 1GB
  
  # Configure dead job handling
  config.death_handlers << ->(job, ex) do
    Rails.logger.error "Job #{job['class']} failed with error: #{ex.message}"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure Sidekiq web interface (optional)
if defined?(Sidekiq::Web)
  Sidekiq::Web.set :sessions, false
  Sidekiq::Web.set :protection, false
end 