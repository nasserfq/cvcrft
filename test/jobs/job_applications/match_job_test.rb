require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::MatchJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @tester = users(:one)
    @other = users(:two)
    create_preference(@tester)
    create_preference(@other)
  end

  test "matches only enabled users" do
    JobApplications::Matcher.expects(:new).with(@tester).returns(stub(call: 1))
    JobApplications::Matcher.expects(:new).with(@other).never

    with_seera_apply_for(@tester) { JobApplications::MatchJob.perform_now }
  end

  test "queues applications for each user it matched" do
    JobApplications::Matcher.stubs(:new).returns(stub(call: 1))

    with_seera_apply_for(@tester) { JobApplications::MatchJob.perform_now }

    assert_enqueued_with(job: JobApplications::QueueJob, args: [ @tester.id ])
    assert_enqueued_jobs 1, only: JobApplications::QueueJob
  end

  test "skips preferences without titles or cities" do
    JobApplications::Preference.find_by!(user: @tester).update!(cities: [])
    JobApplications::Matcher.expects(:new).never

    with_seera_apply_for(@tester) { JobApplications::MatchJob.perform_now }
  end

  test "single-user mode matches that user only" do
    ENV["SEERA_APPLY_ENABLED"] = "true"
    JobApplications::Matcher.expects(:new).with(@other).returns(stub(call: 0))

    JobApplications::MatchJob.perform_now(@other.id)
  ensure
    ENV.delete("SEERA_APPLY_ENABLED")
  end

  test "single-user mode does nothing for a user who is not enabled" do
    JobApplications::Matcher.expects(:new).never

    with_seera_apply_for(@tester) { JobApplications::MatchJob.perform_now(@other.id) }
  end

  test "one user's error is reported and the run goes on" do
    ENV["SEERA_APPLY_ENABLED"] = "true"
    calls = sequence("calls")
    JobApplications::Matcher.any_instance.expects(:call).twice.in_sequence(calls).raises(RuntimeError, "boom").then.returns(1)
    Sentry.expects(:capture_exception).once

    JobApplications::MatchJob.perform_now
  ensure
    ENV.delete("SEERA_APPLY_ENABLED")
  end

  test "an open breaker ends the run without Sentry" do
    ENV["SEERA_APPLY_ENABLED"] = "true"
    JobApplications::Matcher.any_instance.expects(:call).once.raises(AiCircuit::OpenError)
    Sentry.expects(:capture_exception).never

    JobApplications::MatchJob.perform_now
  ensure
    ENV.delete("SEERA_APPLY_ENABLED")
  end
end
