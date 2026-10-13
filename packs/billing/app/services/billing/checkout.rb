module Billing
  # Buying a credit pack. start! makes a pending CreditPurchase and a Moyasar
  # invoice; settle! reads the invoice back from Moyasar and grants the credits
  # once it's paid. settle! never trusts what the browser or the callback says,
  # only what Moyasar's API returns, and it's safe to call more than once.
  class Checkout
    class UnknownPack < StandardError; end

    def initialize(client: MoyasarClient.new)
      @client = client
    end

    # urls: a lambda taking the purchase and returning
    # { success_url:, back_url:, callback_url: }.
    def start!(user, pack_id, urls:)
      pack = Billing.pack(pack_id) or raise UnknownPack, pack_id.to_s

      purchase = CreditPurchase.create!(
        user: user, pack: pack_id.to_s, credits: pack[:credits],
        amount_halalas: pack[:amount_halalas], currency: "SAR"
      )

      invoice = @client.create_invoice(
        amount: purchase.amount_halalas,
        currency: purchase.currency,
        description: I18n.t("billing.invoice_description", credits: purchase.credits, locale: :ar),
        **urls.call(purchase)
      )

      purchase.update!(moyasar_invoice_id: invoice.fetch("id"), checkout_url: invoice.fetch("url"))
      purchase
    rescue MoyasarClient::Error
      purchase&.update!(status: "failed")
      raise
    end

    def settle!(purchase)
      return purchase if purchase.paid? || purchase.moyasar_invoice_id.blank?

      invoice = @client.fetch_invoice(purchase.moyasar_invoice_id)
      return purchase unless invoice["status"] == "paid"

      # The invoice must be the one we created, for the price we stored.
      unless invoice["id"] == purchase.moyasar_invoice_id &&
             invoice["amount"].to_i == purchase.amount_halalas &&
             invoice["currency"].to_s.upcase == purchase.currency
        Rails.logger.error("[billing] invoice #{invoice['id']} does not match purchase #{purchase.id}")
        return purchase
      end

      purchase.with_lock do
        unless purchase.paid?
          Credits.grant!(purchase.user, purchase.credits,
                         reason: "purchase", key: "purchase:#{purchase.id}",
                         metadata: { pack: purchase.pack, moyasar_invoice_id: purchase.moyasar_invoice_id })
          purchase.update!(status: "paid", paid_at: Time.current)
        end
      end
      purchase
    end
  end
end
