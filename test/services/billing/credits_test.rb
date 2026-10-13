require "test_helper"

class Billing::CreditsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "new users get the signup bonus once" do
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_equal 1, @user.credit_ledger_entries.where(reason: "signup_bonus").count
  end

  test "spend takes credits and records the balance after" do
    assert Billing::Credits.spend!(@user, 1, reason: "coach_message", key: "msg:1")

    entry = @user.credit_ledger_entries.find_by(idempotency_key: "msg:1")
    assert_equal(-1, entry.amount)
    assert_equal Billing::SIGNUP_BONUS - 1, entry.balance_after
    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
  end

  test "spend with a repeated key charges once" do
    2.times { assert Billing::Credits.spend!(@user, 1, reason: "coach_message", key: "msg:dup") }

    assert_equal Billing::SIGNUP_BONUS - 1, Billing::Credits.balance(@user)
  end

  test "spend refuses when the balance is too low and records nothing" do
    assert_not Billing::Credits.spend!(@user, Billing::SIGNUP_BONUS + 1, reason: "coach_message", key: "msg:big")

    assert_equal Billing::SIGNUP_BONUS, Billing::Credits.balance(@user)
    assert_nil CreditLedgerEntry.find_by(idempotency_key: "msg:big")
  end

  test "grant with a repeated key grants once" do
    2.times { Billing::Credits.grant!(@user, 100, reason: "purchase", key: "purchase:x") }

    assert_equal Billing::SIGNUP_BONUS + 100, Billing::Credits.balance(@user)
  end

  test "rejects zero or negative amounts" do
    assert_raises(ArgumentError) { Billing::Credits.grant!(@user, 0, reason: "admin_adjustment", key: "a") }
    assert_raises(ArgumentError) { Billing::Credits.spend!(@user, -5, reason: "coach_message", key: "b") }
  end
end
