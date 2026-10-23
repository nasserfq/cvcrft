module Billing
  # The one entry point for AI features that have a free allowance. A use
  # comes out of the free allowance first; once that is gone, and only while
  # billing is on for the user, it costs COSTS[kind] credits. Otherwise it is
  # blocked, as before credits existed.
  #
  # Callers pass a key unique to the request (a job id, a record id). The same
  # key never charges twice, and refund! gives the credit back when the work
  # fails after it was charged.
  class UsageGate
    # Credits per use past the free allowance, weighted by what the use is
    # worth. coach_message is charged by the coach pack, not through allow!.
    COSTS = {
      summary_translation: 1,
      jobs_translation: 1,
      document_ai: 2,
      job_based_generation: 3,
      coach_message: 1
    }.freeze

    REASONS = {
      summary_translation: "overage_summary_translation",
      jobs_translation: "overage_jobs_translation",
      job_based_generation: "overage_job_based_generation",
      document_ai: "overage_document_ai"
    }.freeze

    class << self
      # Records one use. Returns :free, :credit or :blocked; :blocked records
      # nothing. The free counter and the credit balance are both changed
      # under the user's row lock, so parallel requests can't overspend.
      def allow!(user, kind, key:)
        reason = REASONS.fetch(kind)
        ledger_key = charge_key(user, kind, key)

        return :credit if CreditLedgerEntry.exists?(idempotency_key: ledger_key)
        return :free if user.usage_limits.consume!(kind)
        return :blocked unless Billing.enabled_for?(user)

        charged = Credits.spend!(user, cost(kind), reason: reason, key: ledger_key,
                                                    metadata: { "kind" => kind.to_s, "request_key" => key.to_s })
        charged ? :credit : :blocked
      end

      # Gives back the credit allow! took for this key. Returns true when a
      # refund was made (or already made), false when nothing was charged.
      def refund!(user, kind, key:)
        ledger_key = charge_key(user, kind, key)
        charge = CreditLedgerEntry.find_by(idempotency_key: ledger_key, user_id: user.id)
        return false unless charge

        Credits.grant!(user, -charge.amount, reason: "refund", key: "refund:#{ledger_key}",
                                             metadata: { "kind" => kind.to_s, "refunded_entry_id" => charge.id })
        true
      end

      # Whether a use would go through right now, without recording anything.
      def available?(user, kind)
        REASONS.fetch(kind)
        return true if user.usage_limits.free_available?(kind)

        Billing.enabled_for?(user) && Credits.can_spend?(user, cost(kind))
      end

      def cost(kind) = COSTS.fetch(kind)

      # What the next use of each kind would cost, for the frontend to say
      # "this will use N credits" before the user asks.
      def quote(user, kinds)
        enabled = Billing.enabled_for?(user)
        balance = enabled ? Credits.balance(user) : nil

        kinds.index_with do |kind|
          REASONS.fetch(kind)
          free = user.usage_limits.free_available?(kind)
          affordable = enabled && balance >= cost(kind)
          { free_available: free, will_use_credit: !free && affordable, allowed: free || affordable, cost: cost(kind) }
        end.merge(enabled: enabled, balance: balance)
      end

      private

      def charge_key(user, kind, key)
        raise ArgumentError, "key is required" if key.blank?

        "overage:#{kind}:#{user.id}:#{key}"
      end
    end
  end
end
