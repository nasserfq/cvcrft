# config/initializers/redis.rb

# Define a global Redis instance that will be available throughout the application
module RedisProvider
  # Using a module method to create a singleton-like access pattern
  def self.instance
    @redis_instance
  end

  def self.instance=(value)
    @redis_instance = value
  end

  # Mock Redis client for when Redis is not available
  class MockRedis
    def initialize
      @storage = {}
    end

    def get(key)
      @storage[key]
    end

    def setex(key, ttl, value)
      @storage[key] = value
      true
    end

    def ping
      "PONG"
    end

    def keys(pattern)
      @storage.keys.select { |k| File.fnmatch(pattern, k) }
    end

    def method_missing(method, *args, &block)
      Rails.logger.warn "Redis operation '#{method}' called on mock Redis" if defined?(Rails) && Rails.logger
      nil
    end

    def respond_to_missing?(method, include_private = false)
      true
    end
  end
end

# Try to set up the actual Redis connection
begin
  require "redis"

  # Configure Redis for the application
  redis_config = {
    url: ENV["REDIS_URL"] || "redis://localhost:6379/0",
    timeout: 5.0
  }

  # Create a Redis connection
  redis = Redis.new(redis_config)

  # Test the connection to make sure it works
  redis.ping
  Rails.logger.info "Redis connected successfully" if defined?(Rails) && Rails.logger

  # Store the instance
  RedisProvider.instance = redis

rescue LoadError => e
  # Redis gem not available
  if defined?(Rails) && Rails.logger
    Rails.logger.warn "Redis gem not found. Please run 'bundle install'. #{e.message}"
  else
    puts "Warning: Redis gem not found. Please run 'bundle install'. #{e.message}"
  end

  # Use mock Redis
  RedisProvider.instance = RedisProvider::MockRedis.new

rescue => e
  # Redis connection failed
  if defined?(Rails) && Rails.logger
    Rails.logger.error "Failed to connect to Redis: #{e.message}"
  else
    puts "Error: Failed to connect to Redis: #{e.message}"
  end

  # Use mock Redis
  RedisProvider.instance = RedisProvider::MockRedis.new
end

# Define a helper method to get the Redis instance
def redis
  RedisProvider.instance
end
