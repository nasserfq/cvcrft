module Coach
  class TurnJob < ApplicationJob
    queue_as :coach

    # solid_cable stores every broadcast as a row, so stream in batches.
    FLUSH_EVERY = 0.15

    # message_id is the user message this turn answers; jobs queued before it was passed have none.
    def perform(chat_id, message_id = nil)
      chat = Coach::Chat.find(chat_id)
      # Extracted here, not in the upload request, so the request never waits on the LLM.
      if chat.path == "import" && chat.draft.blank?
        chat.update!(draft: AiCircuit.call { Coach::Extract.call(chat.messages.order(:id).first.content) })
        Coach.broadcast(chat, type: "draft", draft: chat.draft)
      end
      # Action Cable can deliver broadcasts out of order, so each chunk carries the whole text so far.
      streamed = +""
      sent = 0
      flushed_at = now
      flush = lambda do
        Coach.broadcast(chat, type: "chunk", text: streamed.dup) if streamed.size > sent
        sent = streamed.size
        flushed_at = now
      end

      # Through AiCircuit like every Bedrock call: while it is open the turn
      # ends below with a refund, without calling the model.
      agent = Coach::Agent.new(chat)
      reply = AiCircuit.call do
        agent.reply do |text|
          streamed << text
          flush.call if now - flushed_at >= FLUSH_EVERY
        end
      end
      flush.call
      # reply is only the text after the last tool call; save everything the user saw.
      answer = chat.messages.create!(role: "assistant", content: streamed.presence || reply, fields: agent.fields)
      Coach.broadcast(chat, type: "done", message_id: answer.id, text: answer.content, fields: answer.fields)
    # Never re-raise: a Sidekiq retry would send the user a second reply.
    rescue => e
      Sentry.capture_exception(e, tags: { pack: "coach" }) unless e.is_a?(AiCircuit::OpenError)
      # A saved reply was paid for and shows on reload, so there is nothing to refund or undo.
      return if chat.nil? || answer&.persisted?

      # The user paid for a reply they didn't get. Refund the message this job
      # answers, not the newest one: overlapping turns each refund their own.
      users = chat.messages.where(role: "user")
      turn = message_id ? users.find_by(id: message_id) : users.order(:id).last
      if turn
        turn.end_turn! # frees the chat for the next message
        Coach.refund!(chat.user, turn)
      end
      Coach.broadcast(chat, type: "error")
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
