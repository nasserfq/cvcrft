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
    assert_equal [ { "type" => "chunk", "text" => "Hello" }, { "type" => "done", "message_id" => message.id, "text" => "Hello", "fields" => [] } ],
                 broadcasts(@stream).map { |b| JSON.parse(b) }
  end

  test "each chunk carries the whole text so far, and text before a tool call is saved too" do
    # RubyLLM returns only the text after the last tool call.
    Coach::Agent.any_instance.stubs(:reply).multiple_yields([ "Great! " ], [ "Your city?" ]).returns("Your city?")

    stub_const(Coach::TurnJob, :FLUSH_EVERY, 0) { Coach::TurnJob.perform_now(@chat.id) }

    chunks = broadcasts(@stream).map { |b| JSON.parse(b) }.select { |b| b["type"] == "chunk" }
    assert_equal [ "Great! ", "Great! Your city?" ], chunks.map { |c| c["text"] }
    assert_equal "Great! Your city?", @chat.messages.order(:id).last.content
  end

  test "boxes the reply asked for are saved and broadcast with done" do
    Coach::Agent.any_instance.stubs(:reply).returns("Your email?")
    Coach::Agent.any_instance.stubs(:fields).returns([ "Email" ])

    Coach::TurnJob.perform_now(@chat.id)

    message = @chat.messages.order(:id).last
    assert_equal [ "Email" ], message.fields
    assert_broadcast_on(@stream, type: "done", message_id: message.id, text: "Your email?", fields: [ "Email" ])
  end

  test "an error is reported and broadcast, and nothing is saved" do
    Coach::Agent.any_instance.stubs(:reply).raises(RuntimeError)
    Sentry.expects(:capture_exception).with(instance_of(RuntimeError), tags: { pack: "coach" })

    assert_no_difference -> { Coach::Message.count } do
      Coach::TurnJob.perform_now(@chat.id)
    end
    assert_broadcast_on(@stream, type: "error")
  end

  test "an import chat with an empty draft is extracted first and the draft broadcast" do
    chat = Coach::Chat.create!(user: users(:one), path: "import")
    chat.messages.create!(role: "user", content: "Sara Ali, cashier at Panda")
    draft = { "complete_name" => "Sara Ali" }
    Coach::Extract.expects(:call).once.with("Sara Ali, cashier at Panda").returns(draft)
    Coach::Agent.any_instance.stubs(:reply).returns("Here is what I read")

    Coach::TurnJob.perform_now(chat.id)

    assert_equal draft, chat.reload.draft
    assert_broadcast_on("coach:#{chat.id}", type: "draft", draft: draft)
  end

  test "an import chat that already has a draft is not extracted again" do
    chat = Coach::Chat.create!(user: users(:one), path: "import", draft: { "complete_name" => "Sara Ali" })
    chat.messages.create!(role: "user", content: "Please review my CV")
    Coach::Extract.expects(:call).never
    Coach::Agent.any_instance.stubs(:reply).returns("Here is what I read")

    Coach::TurnJob.perform_now(chat.id)

    assert_equal "Here is what I read", chat.messages.order(:id).last.content
  end
end
