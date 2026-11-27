require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::TailoredSummaryTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  setup do
    @user = users(:one)
    @resume = finished_resume(@user, professional_summary_english: "Product manager with five years in fintech.")
    @resume.skills.create!(category: "Product", skill_names: [ "Roadmapping" ])
    @posting = create_posting(create_employer(name: "Tamara"), title: "Senior Product Manager", description: "Own the payments roadmap.")
  end

  def summary = JobApplications::TailoredSummary.new(@user, @resume.id, @posting)

  def reply(text) = Struct.new(:content).new(text)

  test "the prompt holds the job and the CV facts but no email or phone" do
    AiModel.expects(:complete).once.with do |args|
      prompt = args[:user]
      prompt.include?("Senior Product Manager at Tamara") && prompt.include?("payments roadmap") &&
        prompt.include?("Roadmapping") && !prompt.include?("sara@example.com") && !prompt.include?("0500000000") &&
        args[:system].include?("3-4 sentences")
    end.returns(reply("Product manager who shipped payments roadmaps."))

    assert_equal "Product manager who shipped payments roadmaps.", summary.call
  end

  test "an Arabic or blank reply falls back to the resume's own summary" do
    AiModel.stubs(:complete).returns(reply("مدير منتجات بخبرة خمس سنوات"))
    assert_equal "Product manager with five years in fintech.", summary.call

    AiModel.stubs(:complete).returns(reply("  "))
    assert_equal "Product manager with five years in fintech.", summary.call
  end
end
