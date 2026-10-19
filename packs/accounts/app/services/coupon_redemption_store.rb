class CouponRedemptionStore
  class Error < StandardError; end

  class << self
    def redeemed?(user_id, code)
      backend.redeemed?(user_id, normalize_code(code))
    end

    def redeem!(user_id, code)
      normalized = normalize_code(code)
      return true if redeemed?(user_id, normalized)

      backend.redeem!(user_id, normalized)
    end

    def redeemed_codes_for(user_id)
      CouponRegistry.all.filter_map do |coupon|
        coupon.code if redeemed?(user_id, coupon.code)
      end
    end

    def forget_user!(user_id)
      backend.forget_user!(user_id)
    end

    def reset!
      backend.reset!
    end

    private

    def normalize_code(code)
      code.to_s.strip.upcase
    end

    def backend
      @backend ||= build_backend
    end

    def build_backend
      if Rails.env.test?
        MemoryBackend.new
      else
        RedisBackend.new
      end
    end
  end

  class MemoryBackend
    def initialize
      @redemptions = Hash.new { |hash, key| hash[key] = Set.new }
    end

    def redeemed?(user_id, code)
      @redemptions[code].include?(user_id.to_s)
    end

    def redeem!(user_id, code)
      @redemptions[code] << user_id.to_s
      true
    end

    def forget_user!(user_id)
      @redemptions.each_value { |user_ids| user_ids.delete(user_id.to_s) }
      true
    end

    def reset!
      @redemptions.clear
    end
  end

  class RedisBackend
    def redeemed?(user_id, code)
      redis.sismember(key(code), user_id.to_s)
    end

    def redeem!(user_id, code)
      redis.sadd(key(code), user_id.to_s)
    end

    def forget_user!(user_id)
      CouponRegistry.all.each { |coupon| redis.srem(key(coupon.code), user_id.to_s) }
      true
    end

    def reset!
      CouponRegistry.all.each { |coupon| redis.del(key(coupon.code)) }
    end

    private

    def key(code)
      "coupon:redemptions:#{code}"
    end

    def redis
      @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    end
  end
end
