module JobApplications
  # One Chromium per host, whatever SIDEKIQ_CONCURRENCY is: a Redis lock
  # (SET NX EX) that a SendJob holds while its browser runs. The TTL frees it
  # if a worker dies holding it.
  module BrowserSlot
    KEY = "seera_apply:browser".freeze
    TTL = 300 # seconds; a browser run is capped at 120

    # Lua: delete the key only if we still hold it.
    RELEASE = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end".freeze

    module_function

    # A token when the slot was free, nil when another browser holds it.
    def acquire
      token = SecureRandom.hex(16)
      Sidekiq.redis { |redis| redis.call("SET", KEY, token, "NX", "EX", TTL) } == "OK" ? token : nil
    end

    def release(token)
      return if token.nil?

      Sidekiq.redis { |redis| redis.call("EVAL", RELEASE, 1, KEY, token) }
    rescue RedisClient::Error => e
      # The TTL frees the slot anyway.
      Rails.logger.warn("[seera_apply] browser slot not released: #{e.class}")
    end
  end
end
