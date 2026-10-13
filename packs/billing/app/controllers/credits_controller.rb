class CreditsController < ApplicationController
  before_action :authenticate_user!, except: :moyasar_callback
  before_action :require_billing!, except: :moyasar_callback
  # Moyasar's server posts here; it has no session or CSRF token.
  skip_before_action :verify_authenticity_token, only: :moyasar_callback

  def index
    @balance = Billing::Credits.balance(current_user)
    @packs = Billing::PACKS
    @entries = current_user.credit_ledger_entries.recent.limit(20)
  end

  def purchase
    purchase = Billing::Checkout.new.start!(current_user, params[:pack], urls: lambda { |p|
      {
        success_url: complete_credits_url(purchase_id: p.id),
        back_url: credits_url,
        callback_url: moyasar_callback_credits_url
      }
    })
    track_event("credits_checkout_started", { pack: purchase.pack, credits: purchase.credits })
    redirect_to purchase.checkout_url, allow_other_host: true
  rescue Billing::Checkout::UnknownPack
    redirect_to credits_path, alert: t("billing.unknown_pack")
  rescue Billing::MoyasarClient::Error => e
    Rails.logger.error("[billing] checkout failed: #{e.message}")
    redirect_to credits_path, alert: t("billing.checkout_failed")
  end

  # Where Moyasar sends the user after paying.
  def complete
    purchase = current_user.credit_purchases.find(params[:purchase_id])
    Billing::Checkout.new.settle!(purchase)

    if purchase.reload.paid?
      track_event("credits_purchased", { pack: purchase.pack, credits: purchase.credits })
      redirect_to credits_path, notice: t("billing.purchase_success", credits: purchase.credits)
    else
      redirect_to credits_path, alert: t("billing.purchase_pending")
    end
  rescue Billing::MoyasarClient::Error => e
    Rails.logger.error("[billing] settle failed: #{e.message}")
    redirect_to credits_path, alert: t("billing.purchase_pending")
  end

  # Moyasar's invoice callback. The body is only a hint: we look the invoice
  # up ourselves, so a forged call can't grant anything.
  def moyasar_callback
    invoice_id = params[:id].presence || params.dig(:data, :invoice_id).presence
    purchase = CreditPurchase.find_by(moyasar_invoice_id: invoice_id.to_s) if invoice_id
    Billing::Checkout.new.settle!(purchase) if purchase
    head :ok
  rescue Billing::MoyasarClient::Error => e
    Rails.logger.error("[billing] callback settle failed: #{e.message}")
    head :service_unavailable
  end

  private

  def require_billing!
    raise ActionController::RoutingError, "Not Found" unless Billing.enabled_for?(current_user)
  end
end
