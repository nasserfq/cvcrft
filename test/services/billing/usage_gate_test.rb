require "test_helper"

class Billing::UsageGateTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Coupon redemptions live in Redis and can leak in from other tests.
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  teardown do
    ENV.delete("BILLING_ENABLED")
  end

  test "uses the free allowance first and charges nothing" do
    ENV["BILLING_ENABLED"] = "true"

    assert_equal :free, Billing::UsageGate.allow!(@user, :summary_translation, key: "free-1")

    assert_equal 1, @user.reload.summary_translations_count
    assert_not CreditLedgerEntry.exists?(reason: "overage_summary_translation")
  end

  test "charges one credit once the free allowance is used up" do
    ENV["BILLING_ENABLED"] = "true"
    exhaust_summary_quota

    assert_equal :credit, Billing::UsageGate.allow!(@user, :summary_translation, key: "job-1")

    entry = CreditLedgerEntry.find_by(reason: "overage_summary_translation")
    assert_equal(-1, entry.amount)
    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
    assert_equal UserUsageLimits::BASE_SUMMARY_TRANSLATIONS, @user.reload.summary_translations_count
  end

  test "a repeated key charges once" do
    ENV["BILLING_ENABLED"] = "true"
    exhaust_jobs_quota

    2.times { assert_equal :credit, Billing::UsageGate.allow!(@user, :jobs_translation, key: "job-dup") }

    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
  end

  test "blocks with no credits left and records nothing" do
    ENV["BILLING_ENABLED"] = "true"
    exhaust_summary_quota
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_column(:credit_balance, 0)

    assert_equal :blocked, Billing::UsageGate.allow!(@user, :summary_translation, key: "job-2")
    assert_not CreditLedgerEntry.exists?(reason: "overage_summary_translation")
    assert_not Billing::UsageGate.available?(@user, :summary_translation)
  end

  test "blocks without touching credits while billing is off" do
    exhaust_summary_quota

    assert_equal :blocked, Billing::UsageGate.allow!(@user, :summary_translation, key: "job-3")
    assert_equal 0, @user.credit_ledger_entries.count
    assert_not Billing::UsageGate.available?(@user, :summary_translation)
  end

  test "refund gives the credit back once" do
    ENV["BILLING_ENABLED"] = "true"
    exhaust_summary_quota
    Billing::UsageGate.allow!(@user, :summary_translation, key: "job-4")

    2.times { assert Billing::UsageGate.refund!(@user, :summary_translation, key: "job-4") }

    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_equal 1, @user.credit_ledger_entries.where(reason: "refund").count
  end

  test "refund without a charge does nothing" do
    assert_not Billing::UsageGate.refund!(@user, :summary_translation, key: "never-charged")
    assert_equal 0, @user.credit_ledger_entries.count
  end

  test "quote says when the next use will cost a credit" do
    ENV["BILLING_ENABLED"] = "true"
    exhaust_summary_quota

    quote = Billing::UsageGate.quote(@user, %i[summary_translation jobs_translation])

    assert quote[:enabled]
    assert_equal Billing::SIGNUP_BONUS, quote[:balance]
    assert quote[:summary_translation][:will_use_credit]
    assert quote[:summary_translation][:allowed]
    assert_not quote[:jobs_translation][:will_use_credit]
    assert quote[:jobs_translation][:free_available]
  end

  test "covers job-based generation and document AI" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_columns(job_based_generations_count: UserUsageLimits::BASE_JOB_BASED_GENERATIONS,
                         document_ai_count: UserUsageLimits::BASE_DOCUMENT_AI)

    assert_equal :credit, Billing::UsageGate.allow!(@user, :job_based_generation, key: "gen-1")
    assert_equal :credit, Billing::UsageGate.allow!(@user, :document_ai, key: "import-1")
    assert CreditLedgerEntry.exists?(reason: "overage_job_based_generation")
    assert CreditLedgerEntry.exists?(reason: "overage_document_ai")
  end

  test "rejects unknown kinds and blank keys" do
    assert_raises(KeyError) { Billing::UsageGate.allow!(@user, :nope, key: "k") }
    assert_raises(ArgumentError) { Billing::UsageGate.allow!(@user, :summary_translation, key: "") }
  end

  private

  def exhaust_summary_quota
    @user.update_column(:summary_translations_count, UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
  end

  def exhaust_jobs_quota
    @user.update_column(:jobs_translations_count, UserUsageLimits::BASE_JOBS_TRANSLATIONS)
  end
end

# Real threads, each with its own connection, so the row lock is exercised.
class Billing::UsageGateRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    ENV["BILLING_ENABLED"] = "true"
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @user = User.create!(email: "race-#{SecureRandom.hex(4)}@example.com", name: "Race User", password: "password123")
    Billing::Credits.ensure_signup_bonus!(@user)
    @user.update_columns(credit_balance: 1, summary_translations_count: UserUsageLimits::BASE_SUMMARY_TRANSLATIONS)
  end

  teardown do
    ENV.delete("BILLING_ENABLED")
    @user&.destroy
  end

  test "parallel requests can't spend the same credit twice" do
    results = Array.new(3) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Billing::UsageGate.allow!(User.find(@user.id), :summary_translation, key: "race-#{i}")
        end
      end
    end.map(&:value)

    assert_equal 1, results.count(:credit)
    assert_equal 2, results.count(:blocked)
    assert_equal 0, @user.reload.credit_balance
  end
end
