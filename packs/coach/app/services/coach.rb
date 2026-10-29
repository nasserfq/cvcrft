# AI Coach. Talks to resume_builder only through ResumeBuilder::PublicApi.
module Coach
  # Off unless COACH_ENABLED is "true". COACH_TESTERS is a comma-separated
  # list of emails that see it while it's off, for trying it in production.
  def self.enabled_for?(user)
    return false unless user
    return true if ENV["COACH_ENABLED"] == "true"

    testers = ENV.fetch("COACH_TESTERS", "").split(",").map { |email| email.strip.downcase }
    testers.include?(user.email.to_s.downcase)
  end

  # Coach::Chat and Coach::Message live in coach_chats and coach_messages.
  def self.table_name_prefix = "coach_"

  def self.broadcast(chat, payload) = ActionCable.server.broadcast("coach:#{chat.id}", payload)

  # Caps each user's model spend per day, paid or not.
  DAILY_LIMIT = 60
  # Every user's first FREE_MESSAGES turns are free. After that, while billing
  # is on, each turn costs Billing::UsageGate.cost(:coach_message) credits.
  # Set in config/deploy.yml; it is the coach's biggest AI cost.
  FREE_MESSAGES = ENV.fetch("COACH_FREE_MESSAGES", 60).to_i

  def self.daily_count(user)
    user_messages(user).where(created_at: Time.current.all_day).count
  end

  def self.daily_cap_reached?(user)
    !user.usage_limits.unlimited_coach? && daily_count(user) >= DAILY_LIMIT
  end

  # Call after the user's message is saved, so it counts itself.
  # Returns :free, :credit or :blocked; :blocked records nothing.
  def self.charge!(user, message)
    return :free if user.usage_limits.unlimited_coach?
    return :free unless Billing.enabled_for?(user)
    return :free if user_messages(user).count <= FREE_MESSAGES

    spent = Billing::Credits.spend!(user, Billing::UsageGate.cost(:coach_message), reason: "coach_message", key: charge_key(message))
    spent ? :credit : :blocked
  end

  # Gives back what charge! took for this message, if anything.
  def self.refund!(user, message)
    charge = CreditLedgerEntry.find_by(idempotency_key: charge_key(message), user_id: user.id)
    return unless charge

    Billing::Credits.grant!(user, -charge.amount, reason: "refund", key: "refund:#{charge.idempotency_key}",
                                                  metadata: { "refunded_entry_id" => charge.id })
  end

  def self.charge_key(message) = "coach_message:#{message.id}"

  def self.user_messages(user)
    Coach::Message.joins(:chat).where(role: "user", coach_chats: { user_id: user.id })
  end
end
