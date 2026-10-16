require "test_helper"

class Coach::AgentTest < ActiveSupport::TestCase
  test "instructions include the draft and differ per path" do
    draft = { "header" => { "complete_name" => "Sara Ali" } }
    scratch = Coach::Agent.new(Coach::Chat.new(path: "scratch", draft: draft)).instructions
    import = Coach::Agent.new(Coach::Chat.new(path: "import", draft: draft)).instructions

    assert_includes scratch, draft.to_json
    assert_includes import, draft.to_json
    assert_not_equal scratch, import
    assert_includes scratch, "Never invent facts"
    assert_includes import, "save_section"
  end

  test "the opening question is left out of the model's history" do
    chat = opened_chat
    # Stubbed: RubyLLM.chat checks Bedrock credentials, which CI doesn't have.
    RubyLLM.stubs(:chat).returns(chain)

    assert_equal "Nice to meet you", Coach::Agent.new(chat).reply { }
  end

  test "a passed-in llm is used instead of RubyLLM" do
    chat = opened_chat
    fake = mock
    fake.expects(:chat).returns(chain)
    RubyLLM.expects(:chat).never

    assert_equal "Nice to meet you", Coach::Agent.new(chat, llm: fake).reply { }
  end

  private

  def opened_chat
    chat = Coach::Chat.create!(user: users(:one), path: "scratch")
    chat.messages.create!(role: "assistant", content: "What's your full name?")
    chat.messages.create!(role: "user", content: "First name: Sara")
    chat
  end

  def chain
    llm = stub
    llm.stubs(:with_instructions).returns(llm)
    llm.stubs(:with_tools).returns(llm)
    llm.expects(:add_message).never
    llm.expects(:ask).with("First name: Sara").returns(stub(content: "Nice to meet you"))
    llm
  end
end
