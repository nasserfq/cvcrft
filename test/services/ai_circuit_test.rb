require "test_helper"

class AiCircuitTest < ActiveSupport::TestCase
  # The test cache is a null store; the breaker needs one that remembers.
  setup do
    @cache = ActiveSupport::Cache::MemoryStore.new
    AiCircuit.stubs(:cache).returns(@cache)
    Sidekiq::Queues.clear_all
  end

  teardown { Sidekiq::Queues.clear_all }

  def fail_once(error = RubyLLM::ServiceUnavailableError.new("down"))
    assert_raises(error.class) { AiCircuit.call { raise error } }
  end

  test "passes the result through while closed" do
    assert_equal :reply, AiCircuit.call { :reply }
    assert_not AiCircuit.open?
  end

  test "opens after five provider failures and then refuses without calling the provider" do
    4.times { fail_once }
    assert_not AiCircuit.open?

    fail_once(Faraday::TimeoutError.new("timeout"))
    assert AiCircuit.open?

    called = false
    assert_raises(AiCircuit::OpenError) { AiCircuit.call { called = true } }
    assert_not called
  end

  test "throttling, server errors and lost connections all count" do
    [ RubyLLM::RateLimitError.new("429"), RubyLLM::ServerError.new("500"), RubyLLM::OverloadedError.new("529"),
      Faraday::ConnectionFailed.new("refused"), Net::ReadTimeout.new ].each { |error| fail_once(error) }

    assert AiCircuit.open?
  end

  test "our own errors never open it" do
    5.times { fail_once(RubyLLM::BadRequestError.new("bad")) }
    5.times { fail_once(RuntimeError.new("bug")) }

    assert_not AiCircuit.open?
  end

  test "failures older than the window are forgotten" do
    4.times { fail_once }
    travel AiCircuit::WINDOW + 1.second do
      fail_once
      assert_not AiCircuit.open?
    end
  end

  test "closes by itself after OPEN_FOR" do
    5.times { fail_once }
    travel AiCircuit::OPEN_FOR + 1.second do
      assert_not AiCircuit.open?
      assert_equal :reply, AiCircuit.call { :reply }
    end
  end

  test "a success closes it and clears the failure count" do
    4.times { fail_once }
    AiCircuit.call { :ok }
    fail_once
    assert_not AiCircuit.open?

    4.times { fail_once }
    assert AiCircuit.open?
    AiCircuit.record_success!
    assert_not AiCircuit.open?
  end

  test "busy while open" do
    assert_not AiCircuit.busy?
    5.times { fail_once }
    assert AiCircuit.busy?
  end

  test "busy when the job's queue holds more than AI_QUEUE_LIMIT jobs" do
    3.times { |i| Sidekiq::Client.push("class" => "CvAnalysisJob", "queue" => "default", "args" => [ i ]) }

    with_queue_limit("3") { assert_not AiCircuit.busy?(queue: "default") }
    with_queue_limit("2") do
      assert AiCircuit.busy?(queue: "default")
      assert_not AiCircuit.busy?(queue: "coach")
    end
  end

  test "the queue limit defaults to 200" do
    with_queue_limit(nil) { assert_equal 200, AiCircuit.queue_limit }
  end

  test "an unknown queue size never blocks" do
    Sidekiq::Testing.stubs(:fake?).returns(false)
    Sidekiq::Queue.any_instance.stubs(:size).raises(RedisClient::CannotConnectError)

    assert_equal 0, AiCircuit.queue_size("default")
  end

  test "retry_delay waits out an open breaker and leaves other errors to the job" do
    delay = AiCircuit.retry_delay(AiCircuit::OpenError.new)
    assert_operator delay, :>=, AiCircuit::OPEN_FOR.to_i
    assert_nil AiCircuit.retry_delay(RuntimeError.new)
  end

  test "AiModel calls go through the breaker" do
    5.times { fail_once }
    RubyLLM.expects(:chat).never

    assert_raises(AiCircuit::OpenError) { AiModel.complete(system: "s", user: "u") }
  end

  private

  def with_queue_limit(value)
    old = ENV["AI_QUEUE_LIMIT"]
    value.nil? ? ENV.delete("AI_QUEUE_LIMIT") : ENV["AI_QUEUE_LIMIT"] = value
    yield
  ensure
    old.nil? ? ENV.delete("AI_QUEUE_LIMIT") : ENV["AI_QUEUE_LIMIT"] = old
  end
end
