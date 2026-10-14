require "test_helper"

class Coach::TurnJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @chat = Coach::Chat.create!(user: users(:one), path: "scratch")
    @chat.messages.create!(role: "user", content: "Hi")
    @stream = "coach:#{@chat.id}"
  end

  test "saves the reply and broadcasts the buffered chunks then done" do
    Coach::Agent.any_instance.stubs(:reply).multiple_yields([ "He" ], [ "llo" ]).returns("Hello")

    Coach::TurnJob.perform_now(@chat.id)

    message = @chat.messages.order(:id).last
    assert_equal [ "assistant", "Hello" ], [ message.role, message.content ]
    # Both chunks arrive within the flush window, so they go out as one broadcast.
    assert_equal [ { "type" => "chunk", "text" => "Hello" }, { "type" => "done", "message_id" => message.id } ],
                 broadcasts(@stream).map { |b| JSON.parse(b) }
  end

  test "an error is reported and broadcast, and nothing is saved" do
    Coach::Agent.any_instance.stubs(:reply).raises(RuntimeError)
    Sentry.expects(:capture_exception).with(instance_of(RuntimeError), tags: { pack: "coach" })

    assert_no_difference -> { Coach::Message.count } do
      Coach::TurnJob.perform_now(@chat.id)
    end
    assert_broadcast_on(@stream, type: "error")
  end
end
