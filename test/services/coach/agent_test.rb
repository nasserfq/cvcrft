require "test_helper"

class Coach::AgentTest < ActiveSupport::TestCase
  test "instructions include the draft and differ per path" do
    draft = { "header" => { "complete_name" => "Sara Ali" } }
    scratch = Coach::Agent.new(Coach::Chat.new(path: "scratch", draft: draft)).instructions
    import = Coach::Agent.new(Coach::Chat.new(path: "import", draft: draft)).instructions

    assert_includes scratch, draft.to_json
    assert_includes import, draft.to_json
    assert_not_equal scratch, import
  end
end
