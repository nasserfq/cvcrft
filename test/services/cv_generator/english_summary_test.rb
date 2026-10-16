require "test_helper"

class CvGenerator::EnglishSummaryTest < ActiveSupport::TestCase
  Reply = Struct.new(:content)

  test "an English summary is kept without calling the model" do
    llm = mock
    llm.expects(:complete).never

    summary = "Product leader with 8 years’ experience — shipped 3 apps."
    assert_equal summary, CvGenerator::EnglishSummary.new(llm: llm).call(summary)
  end

  test "a blank summary is left alone" do
    llm = mock
    llm.expects(:complete).never

    assert_nil CvGenerator::EnglishSummary.new(llm: llm).call(nil)
  end

  test "an Arabic summary is translated" do
    llm = mock
    llm.expects(:complete).with { |args| args[:user] == "مدير منتجات" }.returns(Reply.new("Product manager."))

    assert_equal "Product manager.", CvGenerator::EnglishSummary.new(llm: llm).call("مدير منتجات")
  end

  test "a translation that is still not PDF safe raises" do
    llm = stub(complete: Reply.new("مدير منتجات"))

    assert_raises(CvGenerator::EnglishSummary::NotEnglish) do
      CvGenerator::EnglishSummary.new(llm: llm).call("مدير منتجات")
    end
  end

  test "pdf_safe? accepts only text Helvetica can draw" do
    assert CvGenerator::EnglishSummary.pdf_safe?("Product manager.")
    assert_not CvGenerator::EnglishSummary.pdf_safe?("مدير منتجات")
  end
end
