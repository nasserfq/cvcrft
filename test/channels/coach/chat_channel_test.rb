require "test_helper"

class Coach::ChatChannelTest < ActionCable::Channel::TestCase
  setup do
    @chat = Coach::Chat.create!(user: users(:one), path: "scratch")
  end

  test "streams the user's own chat" do
    stub_connection current_user: users(:one)
    subscribe chat_id: @chat.id

    assert subscription.confirmed?
    assert_has_stream "coach:#{@chat.id}"
  end

  test "rejects another user's chat" do
    stub_connection current_user: users(:two)
    subscribe chat_id: @chat.id

    assert subscription.rejected?
  end
end
