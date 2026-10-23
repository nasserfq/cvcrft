module CreditsHelper
  # The signed-in user's credit balance for the header chip, or nil when
  # billing is off for them. Reads the stored balance; only a user with none
  # yet goes through Billing::Credits, which grants the signup bonus once.
  def header_credit_balance
    return @header_credit_balance if defined?(@header_credit_balance)

    user = current_user if user_signed_in?
    @header_credit_balance =
      if Billing.enabled_for?(user)
        user.credit_balance.to_i.positive? ? user.credit_balance : Billing::Credits.balance(user)
      end
  end

  # What each AI use costs past its free allowance, for copy that lists them.
  def credit_costs
    costs = Billing::UsageGate::COSTS
    { translation: costs[:summary_translation], import: costs[:document_ai], job: costs[:job_based_generation],
      coach: costs[:coach_message], coach_free: Coach::FREE_MESSAGES }
  end
end
