# For AI features that hit a usage or credit limit: the JSON fields that point
# the user at /credits, so a limit isn't a dead end. Empty while billing is off.
module CreditsUpsell
  extend ActiveSupport::Concern

  private

  def credits_upsell
    return {} unless Billing.enabled_for?(current_user)

    { upgrade_url: credits_path, upgrade_label: t("ux_credits.get_credits") }
  end
end
