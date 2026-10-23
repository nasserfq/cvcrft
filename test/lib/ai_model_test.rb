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

  test "complete keeps the cheap reply when Jev passes it" do
    with_env("AI_STRONG_MODEL" => "strong") do
      AiModel.expects(:ask).with("s", "u", 0.7, nil, AiModel.default).returns(reply("cheap"))
      AiModel.expects(:passes?).with("good?", "u", "cheap").returns(true)

      assert_equal "cheap", AiModel.complete(system: "s", user: "u", check: "good?").content
    end
  end

  test "complete regenerates on the strong model when Jev rejects the reply" do
    with_env("AI_STRONG_MODEL" => "strong") do
      AiModel.expects(:ask).with("s", "u", 0.7, nil, AiModel.default).returns(reply("cheap"))
      AiModel.expects(:passes?).returns(false)
      AiModel.expects(:ask).with("s", "u", 0.7, nil, "strong").returns(reply("better"))

      assert_equal "better", AiModel.complete(system: "s", user: "u", check: "good?").content
    end
  end

  test "complete keeps the reply when Jev is unavailable" do
    with_env("AI_STRONG_MODEL" => "strong") do
      AiModel.expects(:ask).once.returns(reply("cheap"))
      AiModel.expects(:passes?).returns(nil)

      assert_equal "cheap", AiModel.complete(system: "s", user: "u", check: "good?").content
    end
  end

  test "passes? is nil without a Jev key" do
    RubyLLM.config.stubs(:typesafe_api_key).returns(nil)
    RubyLLM.expects(:judge).never

    assert_nil AiModel.passes?("good?", "in", "out")
  end

  test "redact hides emails and phone numbers" do
    assert_equal "Mail [email] or call [phone] or [phone].", AiModel.redact("Mail a.b@x.co or call +966 50 123 4567 or 0501234567.")
    assert_equal "2020-01 - 2022-06", AiModel.redact("2020-01 - 2022-06")
  end

  private

  def reply(content) = Struct.new(:content).new(content)

  def with_env(vars)
    old = vars.keys.index_with { ENV[_1] }
    vars.each { ENV[_1] = _2 }
    yield
  ensure
    old.each { ENV[_1] = _2 }
  end
end
