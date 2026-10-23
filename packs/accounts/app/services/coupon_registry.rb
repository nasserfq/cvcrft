require "digest"

# Promo coupons from config/coupons.yml. The repo is public, so the file holds
# each code's SHA-256 (CouponRegistry.digest("CODE")), never the code itself.
# A coupon's `code` is that digest: redemptions are stored under it too.
class CouponRegistry
  class << self
    def all
      @coupons ||= load_coupons
    end

    def find(code)
      return if code.blank?

      fingerprint = digest(code)
      all.find { |coupon| coupon.code == fingerprint }
    end

    # What goes in coupons.yml for a code. Pick long random codes: a short
    # one can be guessed from its digest.
    def digest(code)
      Digest::SHA256.hexdigest(code.to_s.strip.upcase).upcase
    end

    def reload!
      @coupons = nil
    end

    private

    def load_coupons
      path = Rails.env.test? ? Rails.root.join("test/fixtures/files/coupons.yml") : Rails.root.join("config/coupons.yml")
      return [] unless File.exist?(path)

      data = YAML.load_file(path)
      (data.fetch("coupons", nil) || {}).map do |code, attrs|
        ConfigCoupon.new(code, attrs)
      end
    end
  end
end
