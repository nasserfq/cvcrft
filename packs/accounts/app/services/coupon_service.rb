class CouponService
  class Error < StandardError
    attr_reader :code

    def initialize(code, message = nil)
      @code = code
      super(message || code.to_s)
    end
  end

  class InvalidCouponError < Error; end
  class AlreadyRedeemedError < Error; end

  class << self
    def redeem(user, code)
      coupon = CouponRegistry.find(code)
      raise InvalidCouponError.new(:invalid_or_expired) unless coupon&.redeemable?

      if CouponRedemptionStore.redeemed?(user.id, coupon.code)
        raise AlreadyRedeemedError.new(:already_redeemed)
      end

      CouponRedemptionStore.redeem!(user.id, coupon.code)
      if coupon.bonus_credits.positive?
        Billing::Credits.grant!(user, coupon.bonus_credits,
                                reason: "coupon", key: "coupon:#{coupon.code}:#{user.id}",
                                metadata: { coupon: coupon.code })
      end
      coupon
    end
  end
end
