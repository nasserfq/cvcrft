# Credits and payments. Other packs use Billing::Credits to check and spend a
# user's credits; only this pack talks to Moyasar.
module Billing
  # Free credits for every new account. Set in config/deploy.yml so a launch
  # offer can be raised or lowered with one Deploy; accounts that already got
  # it keep it.
  SIGNUP_BONUS = ENV.fetch("SIGNUP_BONUS_CREDITS", 10).to_i

  # Prices in halalas (1 SAR = 100 halalas), shown as final prices.
  PACKS = {
    "credits_100" => { credits: 100, amount_halalas: 19_00 },
    "credits_300" => { credits: 300, amount_halalas: 49_00 }
  }.freeze

  # Off unless BILLING_ENABLED is "true". BILLING_TESTERS is a comma-separated
  # list of emails that see it while it's off, for trying it in production.
  def self.enabled_for?(user)
    return false unless user
    return true if ENV["BILLING_ENABLED"] == "true"

    testers = ENV.fetch("BILLING_TESTERS", "").split(",").map { |email| email.strip.downcase }
    testers.include?(user.email.to_s.downcase)
  end

  def self.pack(id)
    PACKS[id.to_s]
  end
end
