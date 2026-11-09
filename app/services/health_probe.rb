# Answers "can this app reach Postgres and Redis right now?" for /up and the
# admin Health page. Each check is one round trip (SELECT 1, PING) and gives up
# fast, so kamal-proxy and UptimeRobot get an answer even while a part is down.
module HealthProbe
  TIMEOUT = 0.5 # seconds, per Redis connect/read/write and pool wait
  PARTS = %i[database redis].freeze

  # => { database: true, redis: false }
  def self.call
    PARTS.index_with { |part| public_send(:"#{part}_ok?") }
  end

  def self.database_ok?
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }.to_i == 1
  rescue StandardError
    false
  end

  def self.redis_ok?
    redis_pool.with { |connection| connection.call("PING") } == "PONG"
  rescue StandardError
    false
  end

  # Its own small pool with short timeouts and no reconnect retries: the app's
  # other Redis clients wait seconds before giving up.
  def self.redis_pool
    @redis_pool ||= RedisClient.config(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
      connect_timeout: TIMEOUT,
      read_timeout: TIMEOUT,
      write_timeout: TIMEOUT,
      reconnect_attempts: 0
    ).new_pool(size: Integer(ENV.fetch("RAILS_MAX_THREADS", 5)), timeout: TIMEOUT)
  end
end
