require "test_helper"

class Coach::Tools::ReviewCvTest < ActiveSupport::TestCase
  setup do
    @chat = Coach::Chat.create!(user: users(:one), path: "scratch", draft: { "professional_summary" => "Cashier." })
  end

  test "is called review_cv and returns the section scores" do
    scores = { "professional_summary" => 0.5 }
    Coach::Judge.expects(:review).with(@chat.draft).returns(scores)
    tool = Coach::Tools::ReviewCv.new(@chat)

    assert_equal "review_cv", tool.name
    assert_equal scores, tool.call
  end
end
