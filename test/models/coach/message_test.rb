require "test_helper"

class Coach::MessageTest < ActiveSupport::TestCase
  setup do
    @chat = Coach::Chat.create!(user: users(:one), path: "scratch")
  end

  test "role must be user or assistant" do
    assert @chat.messages.new(role: "assistant", content: "Hi").valid?
    assert_not @chat.messages.new(role: "system", content: "Hi").valid?
  end

  test "content must be present" do
    message = @chat.messages.new(role: "user", content: " ")

    assert_not message.valid?
    assert message.errors[:content].any?
  end
end
