require "test_helper"

class Coach::Tools::AskFieldsTest < ActiveSupport::TestCase
  setup do
    @tool = Coach::Tools::AskFields.new(Coach::Chat.new(path: "scratch"))
  end

  test "is called ask_fields and starts with no boxes" do
    assert_equal "ask_fields", @tool.name
    assert_equal [], @tool.labels
  end

  test "keeps the labels it was given" do
    @tool.call(labels: '["Email", " Phone ", ""]')

    assert_equal [ "Email", "Phone" ], @tool.labels
  end

  test "rejects anything but a short JSON array" do
    assert @tool.call(labels: "Email").key?(:error)
    assert @tool.call(labels: (1..7).map(&:to_s).to_json).key?(:error)
    assert_equal [], @tool.labels
  end
end
