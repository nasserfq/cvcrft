require "test_helper"

class Coach::ExtractTest < ActiveSupport::TestCase
  # Stub the whole chain: RubyLLM.chat checks Bedrock credentials, which CI doesn't have.
  def stub_llm(parsed)
    llm = stub(ask: stub(parsed: parsed))
    llm.stubs(:with_instructions).returns(llm)
    llm.stubs(:with_schema).returns(llm)
    RubyLLM.stubs(:chat).returns(llm)
  end

  test "keeps valid sections and drops invalid entries" do
    parsed = {
      "complete_name" => "Sara Ali",
      "email" => "sara@example.com",
      "professional_summary" => "Cashier with five years in retail.",
      "work_experience" => [
        { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01", "responsibilities" => [ "Served customers" ] },
        { "job_title" => "Clerk", "start_date" => "2018-01" } # no company
      ],
      "skills" => [ { "category" => "Tools", "skill_names" => "POS" } ] # skill_names must be an array
    }
    stub_llm(parsed)

    draft = Coach::Extract.call("Sara Ali, cashier at Panda")

    assert_equal "Sara Ali", draft["complete_name"]
    assert_equal "Cashier with five years in retail.", draft["professional_summary"]
    assert_equal [ "Panda" ], draft["work_experience"].map { |w| w["company"] }
    assert_not draft.key?("skills")
  end

  test "an empty reply gives an empty draft" do
    stub_llm(nil)

    assert_equal({}, Coach::Extract.call("…"))
  end
end
