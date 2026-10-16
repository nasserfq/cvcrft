require "test_helper"

class Coach::LlmTest < ActiveSupport::TestCase
  test "the defaults pin today's production models and providers" do
    assert_equal :bedrock, Coach::Llm::PROVIDER
    assert_equal ENV.fetch("COACH_MODEL", "us.anthropic.claude-sonnet-4-6"), Coach::Llm::MODEL
    assert_equal ENV.fetch("COACH_FAST_MODEL", "us.anthropic.claude-haiku-4-5-20251001-v1:0"), Coach::Llm::FAST_MODEL
    assert_equal "jev-latest", Coach::Llm::JUDGE_MODEL
    assert_equal :typesafe, Coach::Llm::JUDGE_PROVIDER
  end

  test "chat uses the main model on Bedrock" do
    chat = stub
    RubyLLM.expects(:chat).with(model: Coach::Llm::MODEL, provider: :bedrock).returns(chat)

    assert_same chat, Coach::Llm.chat
  end

  test "fast_chat uses the fast model on Bedrock" do
    chat = stub
    RubyLLM.expects(:chat).with(model: Coach::Llm::FAST_MODEL, provider: :bedrock).returns(chat)

    assert_same chat, Coach::Llm.fast_chat
  end

  test "judge asks Jev on typesafe" do
    judgment = stub
    RubyLLM.expects(:judge).with("text", questions: { a: 1 }, model: "jev-latest", provider: :typesafe).returns(judgment)

    assert_same judgment, Coach::Llm.judge("text", questions: { a: 1 })
  end

  test "judge? follows the typesafe API key" do
    RubyLLM.config.stubs(:typesafe_api_key).returns("k")
    assert Coach::Llm.judge?

    RubyLLM.config.stubs(:typesafe_api_key).returns(nil)
    assert_not Coach::Llm.judge?

    RubyLLM.config.stubs(:typesafe_api_key).returns("")
    assert_not Coach::Llm.judge?
  end
end
