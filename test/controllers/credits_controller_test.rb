require "test_helper"

class CreditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    ENV["BILLING_ENABLED"] = "true"
  end

  teardown do
    ENV.delete("BILLING_ENABLED")
    ENV.delete("BILLING_TESTERS")
  end

  test "is hidden when billing is off" do
    ENV.delete("BILLING_ENABLED")

    get credits_url
    assert_response :not_found
  end

  test "testers see it while billing is off" do
    ENV.delete("BILLING_ENABLED")
    ENV["BILLING_TESTERS"] = "someone@example.com, #{@user.email.upcase}"

    get credits_url
    assert_response :success
  end

  test "shows the balance with the signup bonus" do
    get credits_url
    assert_response :success
    assert_select "[data-testid=credit-balance]", Billing::SIGNUP_BONUS.to_s
  end

  test "purchase redirects to the Moyasar checkout page" do
    purchase = CreditPurchase.new(pack: "credits_100", credits: 100, checkout_url: "https://checkout.moyasar.com/invoices/abc")
    Billing::Checkout.any_instance.expects(:start!).returns(purchase)
    Billing::MoyasarClient.stubs(:new).returns(mock)

    post purchase_credits_url, params: { pack: "credits_100" }
    assert_redirected_to "https://checkout.moyasar.com/invoices/abc"
  end

  test "complete settles the purchase and confirms" do
    purchase = CreditPurchase.create!(user: @user, pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_c")
    Billing::MoyasarClient.stubs(:new).returns(stub(fetch_invoice: { "id" => "inv_c", "status" => "paid", "amount" => 19_00, "currency" => "SAR" }))

    get complete_credits_url(purchase_id: purchase.id)
    assert_redirected_to credits_path
    assert purchase.reload.paid?
  end

  test "complete can't settle another user's purchase" do
    other = CreditPurchase.create!(user: users(:two), pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_o")

    get complete_credits_url(purchase_id: other.id)
    assert_response :not_found
  end

  test "the Moyasar callback looks the invoice up itself" do
    sign_out @user
    purchase = CreditPurchase.create!(user: @user, pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_cb")
    Billing::MoyasarClient.stubs(:new).returns(stub(fetch_invoice: { "id" => "inv_cb", "status" => "initiated", "amount" => 19_00, "currency" => "SAR" }))

    post moyasar_callback_credits_url, params: { id: "inv_cb", status: "paid" }, as: :json
    assert_response :ok
    assert_equal "pending", purchase.reload.status
  end

  test "the Moyasar callback finds the invoice from a webhook event's data" do
    sign_out @user
    purchase = CreditPurchase.create!(user: @user, pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_wh")
    Billing::MoyasarClient.stubs(:new).returns(stub(fetch_invoice: { "id" => "inv_wh", "status" => "paid", "amount" => 19_00, "currency" => "SAR" }))

    post moyasar_callback_credits_url, params: { id: "evt_1", type: "payment_paid", data: { id: "pay_1", invoice_id: "inv_wh" } }, as: :json
    assert_response :ok
    assert purchase.reload.paid?
  end

  test "the Moyasar callback fails an expired invoice's purchase" do
    sign_out @user
    purchase = CreditPurchase.create!(user: @user, pack: "credits_100", credits: 100, amount_halalas: 19_00, moyasar_invoice_id: "inv_ex")
    Billing::MoyasarClient.stubs(:new).returns(stub(fetch_invoice: { "id" => "inv_ex", "status" => "expired", "amount" => 19_00, "currency" => "SAR" }))

    post moyasar_callback_credits_url, params: { id: "inv_ex" }, as: :json
    assert_response :ok
    assert_equal "failed", purchase.reload.status
  end

  test "the Moyasar callback ignores a body with no known invoice" do
    sign_out @user

    post moyasar_callback_credits_url, params: { data: "x" }, as: :json
    assert_response :ok
  end
end
