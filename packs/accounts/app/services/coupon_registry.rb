class CouponRegistry
  class << self
    def all
      @coupons ||= load_coupons
    end

    def find(code)
      return if code.blank?

      all.find { |coupon| coupon.code == code.to_s.strip.upcase }
    end

    def reload!
      @coupons = nil
    end

    private

    def load_coupons
      path = Rails.root.join("config/coupons.yml")
      return [] unless File.exist?(path)

      data = YAML.load_file(path)
      data.fetch("coupons", {}).map do |code, attrs|
        ConfigCoupon.new(code, attrs)
      end
    end
  end
end
