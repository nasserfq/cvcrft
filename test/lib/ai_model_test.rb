require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "json_body returns bare JSON as is" do
    assert_equal '{"a":1}', AiModel.json_body('{"a":1}')
  end

  test "json_body unwraps a fenced reply" do
    assert_equal '{"a":1}', AiModel.json_body("Here it is:\n```json\n{\"a\":1}\n```\nDone.")
  end

  test "json_body strips an opening fence that has no closing fence" do
    assert_equal '{"a":1', AiModel.json_body("```json\n{\"a\":1")
  end
end
