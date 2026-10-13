require "test_helper"

class Billing::CheckoutTest < ActiveSupport::TestCase
  URLS = ->(_purchase) { { success_url: "https://x/ok", back_url: "https://x/back", callback_url: "https://x/cb" } }

  setup do
    @user = users(:one)
    @client = mock("moyasar")
    @checkout = Billing::Checkout.new(client: @client)
  end

  test "start creates a pending purchase with the pack's price and the invoice url" do
    @client.expects(:create_invoice).with { |args| args[:amount] == 19_00 && args[:currency] == "SAR" }
           .returns("id" => "inv_1", "url" => "https://checkout.moyasar.com/invoices/inv_1")

    purchase = @checkout.start!(@user, "credits_100", urls: URLS)

    assert_equal "pending", purchase.status
    assert_equal 100, purchase.credits
    assert_equal "inv_1", purchase.moyasar_invoice_id
    assert_equal "https://checkout.moyasar.com/invoices/inv_1", purchase.checkout_url
  end

  test "start rejects an unknown pack" do
    assert_raises(Billing::Checkout::UnknownPack) { @checkout.start!(@user, "free_money", urls: URLS) }
  end

  test "start marks the purchase failed when Moyasar errors" do
    @client.expects(:create_invoice).raises(Billing::MoyasarClient::Error, "down")

    assert_raises(Billing::MoyasarClient::Error) { @checkout.start!(@user, "credits_100", urls: URLS) }
    assert_equal "failed", CreditPurchase.last.status
  end

  test "settle grants credits once when the invoice is paid" do
    purchase = pending_purchase
    @client.expects(:fetch_invoice).with("inv_2").returns(paid_invoice).once

    2.times { @checkout.settle!(purchase) }
    @checkout.settle!(CreditPurchase.find(purchase.id)) # already paid: no fetch

    assert purchase.reload.paid?
    assert_equal Billing::SIGNUP_BONUS + 100, Billing::Credits.balance(@user)
  end

  test "settle grants nothing while the invoice is unpaid" do
    purchase = pending_purchase
    @client.expects(:fetch_invoice).returns(paid_invoice.merge("status" => "initiated"))

    @checkout.settle!(purchase)

    assert_equal "pending", purchase.reload.status
    assert_nil CreditLedgerEntry.find_by(idempotency_key: "purchase:#{purchase.id}")
  end

  test "settle grants nothing when the paid amount doesn't match" do
    purchase = pending_purchase
    @client.expects(:fetch_invoice).returns(paid_invoice.merge("amount" => 100))

    @checkout.settle!(purchase)

    assert_equal "pending", purchase.reload.status
  end

  private

  def pending_purchase
    CreditPurchase.create!(user: @user, pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_2")
  end

  def paid_invoice
    { "id" => "inv_2", "status" => "paid", "amount" => 19_00, "currency" => "SAR" }
  end
end
