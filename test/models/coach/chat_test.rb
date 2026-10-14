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
end
