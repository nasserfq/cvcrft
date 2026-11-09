require "test_helper"

class Coach::ChatTest < ActiveSupport::TestCase
  test "rejects a path outside PATHS" do
    chat = Coach::Chat.new(user: users(:one), path: "other")

    assert_not chat.valid?
    assert chat.errors[:path].any?
  end

  test "deleting the user deletes their chats and messages" do
    user = User.create!(email: "coach-cascade@example.com", name: "Cascade", password: "password123")
    chat = Coach::Chat.create!(user: user, path: "scratch")
    chat.messages.create!(role: "user", content: "Hi")

    User.where(id: user.id).delete_all

    assert_not Coach::Chat.exists?(chat.id)
    assert_equal 0, Coach::Message.where(coach_chat_id: chat.id).count
  end

  test "a turn runs from the user's message until the reply" do
    chat = Coach::Chat.create!(user: users(:one), path: "scratch")
    assert_not chat.turn_running?

    chat.messages.create!(role: "user", content: "Hi")
    assert chat.turn_running?

    chat.messages.create!(role: "assistant", content: "Hello")
    assert_not chat.turn_running?
  end

  test "a turn that ended without a reply, or ran past the timeout, no longer runs" do
    chat = Coach::Chat.create!(user: users(:one), path: "scratch")
    message = chat.messages.create!(role: "user", content: "Hi")

    travel 1.second
    message.end_turn!
    assert_not chat.turn_running?

    chat.messages.create!(role: "user", content: "Again")
    travel Coach::Chat::TURN_TIMEOUT + 1.second
    assert_not chat.turn_running?
  end
end
