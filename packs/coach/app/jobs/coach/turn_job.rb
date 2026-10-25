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
        chat.update!(draft: Coach::Extract.call(chat.messages.order(:id).first.content))
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

      agent = Coach::Agent.new(chat)
      reply = agent.reply do |text|
        streamed << text
        flush.call if now - flushed_at >= FLUSH_EVERY
      end
      flush.call
      # reply is only the text after the last tool call; save everything the user saw.
      message = chat.messages.create!(role: "assistant", content: streamed.presence || reply, fields: agent.fields)
      Coach.broadcast(chat, type: "done", message_id: message.id, text: message.content, fields: message.fields)
    # Never re-raise: a Sidekiq retry would send the user a second reply.
    rescue => e
      Sentry.capture_exception(e, tags: { pack: "coach" })
      return unless chat

      # The user paid for a reply they didn't get. Refund the message this job
      # answers, not the newest one: overlapping turns each refund their own.
      users = chat.messages.where(role: "user")
      turn = message_id ? users.find_by(id: message_id) : users.order(:id).last
      Coach.refund!(chat.user, turn) if turn
      Coach.broadcast(chat, type: "error")
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
