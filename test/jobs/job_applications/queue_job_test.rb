require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::QueueJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @user = users(:one)
    create_profile(@user)
  end

  def run_job = with_seera_apply_for(@user) { JobApplications::QueueJob.perform_now(@user.id) }

  test "queues matches at or above the apply score that have no application" do
    good = create_match(@user, score: 8)
    create_match(@user, score: 7)
    done = create_match(@user, score: 9)
    create_application(@user, posting: done.posting, status: "sent")

    run_job

    app = JobApplications::Application.find_by!(user: @user, posting: good.posting)
    assert_equal [ "preparing", "browser" ], [ app.status, app.channel ]
    assert_equal 2, JobApplications::Application.where(user: @user).count
    assert_enqueued_with(job: JobApplications::PrepareJob, args: [ app.id ])
    assert_enqueued_jobs 1
  end

  test "picks the channel: browser for supported ATS, email with an address, manual otherwise" do
    email = create_match(@user, posting: create_posting(create_employer(ats: "workday"), apply_email: "jobs@example.com"))
    manual = create_match(@user, posting: create_posting(create_employer(ats: "lever")))
    browser = create_match(@user, posting: create_posting(create_employer(ats: "ashby")))

    run_job

    channels = JobApplications::Application.where(user: @user).to_h { |a| [ a.posting_id, a.channel ] }
    assert_equal({ email.posting_id => "email", manual.posting_id => "manual", browser.posting_id => "browser" }, channels)
  end

  test "takes no more than the daily pack limit, browser and email first" do
    manual = create_match(@user, score: 10, posting: create_posting(create_employer(ats: "lever")))
    JobApplications::AiUsage.bump!(@user, :packs, JobApplications::DAILY_PACK_LIMIT - 2)
    create_match(@user)
    create_match(@user)

    run_job

    assert_equal 2, JobApplications::Application.where(user: @user).count
    assert_not JobApplications::Application.exists?(posting: manual.posting)

    run_job
    assert_equal 2, JobApplications::Application.where(user: @user).count
  end

  test "rows still preparing count against the limit" do
    JobApplications::AiUsage.bump!(@user, :packs, JobApplications::DAILY_PACK_LIMIT - 1)
    create_application(@user, status: "preparing")
    create_match(@user)

    run_job

    assert_equal 1, JobApplications::Application.where(user: @user).count
  end

  test "does nothing unless sending is on with consent" do
    create_match(@user)
    profile = JobApplications::Profile.find_by!(user: @user)

    profile.pause!
    run_job
    profile.update!(state: "on", consent_version: nil)
    run_job

    assert_not JobApplications::Application.exists?(user: @user)
  end

  test "does nothing without a profile or when the gate is off" do
    create_match(@user)
    JobApplications::QueueJob.perform_now(@user.id)
    assert_not JobApplications::Application.exists?(user: @user)

    other = users(:two)
    create_match(other)
    with_seera_apply_for(other) { JobApplications::QueueJob.perform_now(other.id) }
    assert_not JobApplications::Application.exists?(user: other)
  end

  test "skips closed postings" do
    match = create_match(@user)
    match.posting.update!(closed_at: Time.current)

    run_job

    assert_not JobApplications::Application.exists?(user: @user)
  end
end
