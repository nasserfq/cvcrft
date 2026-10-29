# Owner-only unlimited coupon

Goal: a coupon that gives Nasser unlimited use of every AI feature, including the coach, and that nobody else can redeem. The repo is public, so neither the code nor the email appears in plain text.

## Unit 1 (packs/accounts, packs/coach, config/coupons.yml, tests)

1. `ConfigCoupon` (packs/accounts/app/services/config_coupon.rb)
   - New optional attr `emails`: a list of SHA-256 digests, made with `CouponRegistry.digest(email)` (same strip+upcase digest as codes). Normalise to upcased strings.
   - New optional boolean attr `unlimited_coach` (default false).
   - `allowed_for?(user)`: true when `emails` is empty; else `emails.include?(CouponRegistry.digest(user.email))`.
   - `unlimited_coach?` reader.
2. `CouponService.redeem`: if `!coupon.allowed_for?(user)` raise the same `InvalidCouponError.new(:invalid_or_expired)` (don't reveal that the code exists).
3. `UserUsageLimits`
   - `unlimited?` and new `unlimited_coach?` only count redeemed coupons whose `allowed_for?(@user)` is true (so a restricted coupon never applies to another account, even if redeemed before).
4. Coach (packs/coach/app/services/coach.rb, packs/coach/app/controllers/coach/chats_controller.rb)
   - `Coach.charge!` returns `:free` first thing when `user.usage_limits.unlimited_coach?`.
   - The two `Coach::DAILY_LIMIT` checks in chats_controller skip users with `unlimited_coach?`. Add a small helper (e.g. `Coach.daily_cap_reached?(user)`) instead of repeating the condition.
   - Only coupons with `unlimited_coach: true` change coach behaviour; the existing unlimited coupon keeps today's coach limits.
5. config/coupons.yml: add, after the existing entry, keeping the file's comment style:
   ```yaml
   # Nasser's own unlimited access; only his account can redeem it
   2769C4A506902D7E335FA656650F7C620955FF4B67CDF1B03A64403F8CC199BF:
     description: Owner unlimited access
     active: true
     unlimited: true
     unlimited_coach: true
     emails:
       - B6BF7649A9F0A111E2F6BFF8C06054E1B31F4173DE7F439D26CF8FD26A5A86D5
   ```
   Also update the header comment with one line on `emails:` (digests of allowed account emails).
6. Tests (test/models/coupon_test.rb, test/fixtures/files/coupons.yml, test/controllers/api/coupons_controller_test.rb or a coach test as fits): add a fixture coupon restricted by email digest with unlimited_coach. Cover: allowed user redeems and gets unlimited; other user gets invalid_or_expired; Coach.charge! returns :free and daily cap is skipped for the allowed user; existing unlimited coupon still does not skip coach charges.
