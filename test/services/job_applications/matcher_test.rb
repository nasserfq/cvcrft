require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::MatcherTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  M = JobApplications::Match

  setup do
    @user = users(:one)
    @resume = finished_resume(@user)
    @preference = create_preference(@user, titles: [ "Product Manager" ], cities: %w[riyadh remote])
  end

  def reply(scores)
    Struct.new(:content).new({ "scores" => scores }.to_json)
  end

  def scores_for(*postings, score: 8)
    postings.map { |p| { "posting_id" => p.id, "score" => score, "reason" => "  Good   fit. " } }
  end

  test "scores only postings whose title and city match" do
    pm = create_posting
    remote = create_posting(create_employer, title: "Senior Product Manager", location: "Remote", city: "remote")
    create_posting(create_employer, title: "Accountant")
    create_posting(create_employer, title: "Product Manager", location: "Jeddah", city: "jeddah")
    create_posting(create_employer, closed_at: 1.hour.ago)
    create_posting(create_employer, fetched_at: 3.days.ago)
    AiModel.expects(:complete).once.returns(reply(scores_for(pm, remote)))

    assert_equal 2, JobApplications::Matcher.new(@user).call

    assert_equal [ pm.id, remote.id ].sort, M.where(user: @user).pluck(:posting_id).sort
    assert_equal "Good fit.", M.find_by!(posting: pm).score_reason
    assert_equal 2, JobApplications::AiUsage.for(@user).scores
  end

  test "never scores a posting twice" do
    posting = create_posting
    create_match(@user, posting:, score: 3)
    AiModel.expects(:complete).never

    assert_equal 0, JobApplications::Matcher.new(@user).call
  end

  test "low scores are stored but not shown, and scores are clamped" do
    low = create_posting
    high = create_posting
    AiModel.stubs(:complete).returns(reply([ { "posting_id" => low.id, "score" => 2 }, { "posting_id" => high.id, "score" => 42 } ]))

    assert_equal 2, JobApplications::Matcher.new(@user).call

    assert_equal 10, M.find_by!(posting: high).score
    assert_equal [ high.id ], M.shown.where(user: @user).pluck(:posting_id)
  end

  test "stops at the daily limit" do
    JobApplications::AiUsage.bump!(@user, :scores, JobApplications::DAILY_SCORE_LIMIT - 2)
    postings = Array.new(4) { create_posting }
    AiModel.expects(:complete).once.with { |user:, **| user.scan('"posting_id"').size == 2 }.returns(reply([]))

    JobApplications::Matcher.new(@user).call

    assert_equal JobApplications::DAILY_SCORE_LIMIT, JobApplications::AiUsage.for(@user).scores
    assert_equal 0, JobApplications::AiUsage.remaining(@user, :scores, JobApplications::DAILY_SCORE_LIMIT)
    assert_equal 4, postings.size
  end

  test "a run that overlaps another for the same user stays within the daily limit" do
    Array.new(10) { create_posting }
    JobApplications::AiUsage.bump!(@user, :scores, JobApplications::DAILY_SCORE_LIMIT - 10)
    # While the first batch is out, another run spends the rest of today's budget.
    AiModel.expects(:complete).once.with { |**|
      JobApplications::AiUsage.reserve!(@user, :scores, 5, JobApplications::DAILY_SCORE_LIMIT)
      true
    }.returns(reply([]))

    JobApplications::Matcher.new(@user).call

    assert_equal JobApplications::DAILY_SCORE_LIMIT, JobApplications::AiUsage.for(@user).scores
  end

  test "batches five postings per call" do
    Array.new(7) { create_posting }
    AiModel.expects(:complete).twice.returns(reply([]))

    JobApplications::Matcher.new(@user).call

    assert_equal 7, JobApplications::AiUsage.for(@user).scores
  end

  test "a bad reply writes nothing but still counts" do
    create_posting
    AiModel.stubs(:complete).returns(Struct.new(:content).new("not json"))

    assert_equal 0, JobApplications::Matcher.new(@user).call

    assert_equal 0, M.where(user: @user).count
    assert_equal 1, JobApplications::AiUsage.for(@user).scores
  end

  test "a provider error counts and writes nothing" do
    create_posting
    stub_ai_failure

    assert_equal 0, JobApplications::Matcher.new(@user).call
    assert_equal 1, JobApplications::AiUsage.for(@user).scores
  end

  test "an open breaker counts nothing and raises" do
    create_posting
    stub_ai_failure(AiCircuit::OpenError.new)

    assert_raises(AiCircuit::OpenError) { JobApplications::Matcher.new(@user).call }
    assert_equal 0, JobApplications::AiUsage.for(@user).scores
  end

  test "no finished CV means no AI call" do
    @resume.update!(is_draft: true)
    create_posting
    AiModel.expects(:complete).never

    assert_equal 0, JobApplications::Matcher.new(@user).call
  end

  test "no preference or no cities means no AI call" do
    create_posting
    AiModel.expects(:complete).never

    assert_equal 0, JobApplications::Matcher.new(users(:two)).call
    @preference.update!(cities: [])
    assert_equal 0, JobApplications::Matcher.new(@user).call
  end

  test "the prompt carries no name, email or phone" do
    @resume.work_experiences.create!(job_title: "Product Manager", company: "Noon", start_date: "2020-01")
    create_posting
    AiModel.expects(:complete).with { |user:, **|
      %w[Sara sara@example.com 0500000000].none? { |s| user.include?(s) } && user.include?("Noon")
    }.returns(reply([]))

    JobApplications::Matcher.new(@user).call
  end
end
