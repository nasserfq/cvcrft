module Coach
  class TurnJob < ApplicationJob
    queue_as :coach

    # solid_cable stores every broadcast as a row, so stream in batches.
    FLUSH_EVERY = 0.15

    def perform(chat_id)
      chat = Coach::Chat.find(chat_id)
      buffer = +""
      flushed_at = now
      flush = lambda do
        Coach.broadcast(chat, type: "chunk", text: buffer.dup) unless buffer.empty?
        buffer.clear
        flushed_at = now
      end

      reply = Coach::Agent.new(chat).reply do |text|
        buffer << text
        flush.call if now - flushed_at >= FLUSH_EVERY
      end
      flush.call
      message = chat.messages.create!(role: "assistant", content: reply)
      Coach.broadcast(chat, type: "done", message_id: message.id)
    # Never re-raise: a Sidekiq retry would send the user a second reply.
    rescue => e
      Sentry.capture_exception(e, tags: { pack: "coach" })
      Coach.broadcast(chat, type: "error") if chat
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
