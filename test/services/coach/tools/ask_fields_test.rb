require "test_helper"

class Coach::Tools::AskFieldsTest < ActiveSupport::TestCase
  setup do
    @tool = Coach::Tools::AskFields.new(Coach::Chat.new(path: "scratch"))
  end

  test "is called ask_fields and starts with no boxes" do
    assert_equal "ask_fields", @tool.name
    assert_equal [], @tool.fields
  end

  test "keeps the boxes it was given; unknown types and bare labels become text" do
    @tool.call(fields: [ { label: "City", type: "city" }, { label: " Dates ", type: "date_range" },
                         { label: "Phone", type: "radio" }, "Email", { label: "" } ].to_json)

    assert_equal [ { "label" => "City", "type" => "city" }, { "label" => "Dates", "type" => "date_range" },
                   { "label" => "Phone", "type" => "text" }, { "label" => "Email", "type" => "text" } ], @tool.fields
  end

  test "rejects anything but a short JSON array" do
    assert @tool.call(fields: "Email").key?(:error)
    assert @tool.call(fields: (1..7).map(&:to_s).to_json).key?(:error)
    assert_equal [], @tool.fields
  end
end
