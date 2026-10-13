module Billing
  # The credit wallet. Every change is a CreditLedgerEntry plus an update of
  # users.credit_balance, both under the user's row lock, so parallel requests
  # can't overspend and a repeated idempotency key is a no-op.
  class Credits
    class << self
      def balance(user)
        ensure_signup_bonus!(user)
        user.reload.credit_balance
      end

      # Gives every user their free credits once, the first time billing
      # looks at them.
      def ensure_signup_bonus!(user)
        grant!(user, SIGNUP_BONUS, reason: "signup_bonus", key: "signup_bonus:#{user.id}")
      end

      # Returns the entry, or the existing one when the key was used before.
      def grant!(user, amount, reason:, key:, metadata: {})
        raise ArgumentError, "amount must be positive" unless amount.to_i.positive?

        record!(user, amount.to_i, reason:, key:, metadata:)
      end

      # Takes credits for one use of an AI feature. Returns false, recording
      # nothing, when the balance is too low. A repeated key returns true
      # without charging again.
      def spend!(user, amount = 1, reason:, key:, metadata: {})
        raise ArgumentError, "amount must be positive" unless amount.to_i.positive?

        ensure_signup_bonus!(user)
        user.with_lock do
          if CreditLedgerEntry.exists?(idempotency_key: key)
            true
          elsif user.credit_balance < amount.to_i
            false
          else
            insert!(user, -amount.to_i, reason:, key:, metadata:)
            true
          end
        end
      end

      def can_spend?(user, amount = 1)
        balance(user) >= amount
      end

      private

      def record!(user, amount, reason:, key:, metadata:)
        user.with_lock do
          CreditLedgerEntry.find_by(idempotency_key: key) || insert!(user, amount, reason:, key:, metadata:)
        end
      end

      # Caller holds the user's lock.
      def insert!(user, amount, reason:, key:, metadata:)
        new_balance = user.credit_balance + amount
        user.update_column(:credit_balance, new_balance)
        CreditLedgerEntry.create!(
          user: user, amount: amount, balance_after: new_balance,
          reason: reason, idempotency_key: key, metadata: metadata
        )
      end
    end
  end
end
