require "sidekiq/api"

# Circuit breaker and backpressure for the AI provider (Bedrock through RubyLLM).
#
# Breaker: FAILURE_LIMIT provider failures (timeouts, 5xx, throttling, lost
# connections) within WINDOW open it for OPEN_FOR. While open, `call` raises
# OpenError without reaching the provider, and controllers refuse new AI work
# before anything is charged. A success closes it. State lives in Rails.cache
# (Solid Cache in production), so web and Sidekiq share it.
#
# Backpressure: `busy?` is also true when the Sidekiq queue an AI job uses has
# more than AI_QUEUE_LIMIT jobs waiting.
module AiCircuit
  FAILURE_LIMIT = 5
  WINDOW = 60.seconds
  OPEN_FOR = 60.seconds
  DEFAULT_QUEUE = "default"
  DEFAULT_QUEUE_LIMIT = 200

  FAILURES_KEY = "ai_circuit:failures"
  OPEN_KEY = "ai_circuit:open_until"

  # Errors that say the provider is down or overloaded. A bad request, a
  # missing model or bad keys are our own fault and never open the breaker.
  PROVIDER_FAILURES = [
    RubyLLM::RateLimitError, RubyLLM::OverloadedError, RubyLLM::ServerError,
    RubyLLM::ServiceUnavailableError, Faraday::TimeoutError, Faraday::ConnectionFailed,
    Net::OpenTimeout, Net::ReadTimeout
  ].freeze

  # Raised instead of calling the provider while the breaker is open. Jobs
  # treat it as retryable: the row stays processing and nothing is charged
  # again (charges happen in controllers, once).
  class OpenError < StandardError
    def initialize(message = "AI provider unavailable (circuit open)")
      super
    end
  end

  module_function

  # Runs one provider call through the breaker.
  def call
    raise OpenError if open?

    result = yield
    record_success!
    result
  rescue *PROVIDER_FAILURES
    record_failure!
    raise
  end

  def open?
    cache.read(OPEN_KEY).present?
  end

  # New AI work is refused while true: the breaker is open or the queue is full.
  def busy?(queue: DEFAULT_QUEUE)
    open? || queue_size(queue) > queue_limit
  end

  def record_failure!
    count = cache.increment(FAILURES_KEY, 1, expires_in: WINDOW).to_i
    return if count < FAILURE_LIMIT

    cache.delete(FAILURES_KEY)
    opened = cache.write(OPEN_KEY, OPEN_FOR.from_now.to_i, expires_in: OPEN_FOR, unless_exist: true)
    Rails.logger.warn("[AiCircuit] open for #{OPEN_FOR.to_i}s after #{count} provider failures") if opened
  end

  def record_success!
    cache.delete_multi([ FAILURES_KEY, OPEN_KEY ])
  end

  # Sidekiq retry delay for a job stopped by an open breaker: after it has
  # closed, so the retry reaches the provider instead of using up attempts.
  # Nil for any other error, so the job's own backoff applies.
  def retry_delay(error)
    OPEN_FOR.to_i + rand(30) if error.is_a?(OpenError)
  end

  def queue_limit
    ENV.fetch("AI_QUEUE_LIMIT", DEFAULT_QUEUE_LIMIT).to_i
  end

  # Jobs waiting in a Sidekiq queue. In Sidekiq's fake test mode the queue is
  # the in-memory array. Redis down counts as empty: backpressure never blocks
  # on its own outage (the enqueue then fails and refunds as before).
  def queue_size(queue)
    return Sidekiq::Queues[queue.to_s].size if defined?(Sidekiq::Testing) && Sidekiq::Testing.fake?

    Sidekiq::Queue.new(queue.to_s).size
  rescue RedisClient::Error => e
    Rails.logger.warn("[AiCircuit] queue size unknown: #{e.class}")
    0
  end

  def cache
    Rails.cache
  end
end
