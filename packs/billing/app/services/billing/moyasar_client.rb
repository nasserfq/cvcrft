require "net/http"

module Billing
  # Moyasar's hosted invoices: we create an invoice, send the user to its
  # checkout page (mada, Apple Pay, STC Pay, cards), and read the invoice back
  # to see whether it was paid. Only the secret key is needed.
  class MoyasarClient
    BASE_URL = "https://api.moyasar.com/v1".freeze

    class Error < StandardError; end

    def initialize(secret_key: ENV["MOYASAR_SECRET_KEY"])
      raise Error, "MOYASAR_SECRET_KEY is not set" if secret_key.blank?

      @secret_key = secret_key
    end

    def create_invoice(amount:, currency:, description:, success_url:, back_url:, callback_url:)
      request(Net::HTTP::Post, "/invoices", {
        amount: amount,
        currency: currency,
        description: description,
        success_url: success_url,
        back_url: back_url,
        callback_url: callback_url
      })
    end

    def fetch_invoice(id)
      request(Net::HTTP::Get, "/invoices/#{ERB::Util.url_encode(id)}")
    end

    private

    def request(klass, path, body = nil)
      uri = URI("#{BASE_URL}#{path}")
      req = klass.new(uri)
      req.basic_auth(@secret_key, "")
      req["Accept"] = "application/json"
      if body
        req["Content-Type"] = "application/json"
        req.body = body.to_json
      end

      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        http.request(req)
      end
      data = JSON.parse(res.body.presence || "{}")
      raise Error, "Moyasar #{res.code}: #{data['message'] || res.body.to_s.truncate(200)}" unless res.is_a?(Net::HTTPSuccess)

      data
    rescue JSON::ParserError
      raise Error, "Moyasar #{res&.code}: response was not JSON"
    end
  end
end
