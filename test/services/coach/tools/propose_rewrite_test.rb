require "test_helper"

class Coach::Tools::ProposeRewriteTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @draft = {
      "professional_summary" => "I work hard.",
      "work_experience" => [ { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01",
                               "responsibilities" => [ "Did the till" ] } ]
    }
    @chat = Coach::Chat.create!(user: users(:one), path: "import", draft: @draft)
    @tool = Coach::Tools::ProposeRewrite.new(@chat)
  end

  test "is called propose_rewrite" do
    assert_equal "propose_rewrite", @tool.name
  end

  test "stores a responsibilities rewrite with its before and broadcasts it" do
    @tool.call(section: "work_experience", index: 0, after: "Handled 300+ payments a day\nResolved customer issues")

    proposal = @chat.reload.proposals.sole
    assert_equal [ "work_experience", 0, "responsibilities" ], proposal.values_at("section", "index", "field")
    assert_equal [ "Did the till" ], proposal["before"]
    assert_equal [ "Handled 300+ payments a day", "Resolved customer issues" ], proposal["after"]
    assert_equal @draft, @chat.draft
    assert_broadcast_on("coach:#{@chat.id}", type: "proposal", proposal: proposal)
  end

  test "stores a summary rewrite" do
    @tool.call(section: "professional_summary", after: "Retail cashier who keeps queues short.")

    assert_equal [ "I work hard.", "Retail cashier who keeps queues short." ], @chat.reload.proposals.sole.values_at("before", "after")
  end

  test "a bad index returns an error and stores nothing" do
    result = @tool.call(section: "work_experience", index: 3, after: "Anything")

    assert_includes result[:error], "index 3 does not exist"
    assert_empty @chat.reload.proposals
    assert_no_broadcasts("coach:#{@chat.id}")
  end

  test "a section that can't be rewritten returns an error" do
    assert @tool.call(section: "education", index: 0, after: "x")[:error].present?
    assert_empty @chat.reload.proposals
  end
end
