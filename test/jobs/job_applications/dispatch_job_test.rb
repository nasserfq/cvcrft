require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::DispatchJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup { @user = users(:one) }

  test "enqueues one SendJob per user for the oldest queued row, approved first" do
    oldest = create_application(@user, created_at: 2.days.ago)
    approved = create_application(@user, approved_at: 1.hour.ago)
    create_application(@user, status: "needs_approval", created_at: 3.days.ago)

    with_seera_apply_for(@user) { JobApplications::DispatchJob.perform_now }

    assert_enqueued_jobs 1, only: JobApplications::SendJob
    assert_enqueued_with(job: JobApplications::SendJob, args: [ approved.id ])
    assert oldest
  end

  test "takes the oldest queued row when none is approved" do
    create_application(@user, created_at: 1.day.ago)
    oldest = create_application(@user, created_at: 2.days.ago)

    with_seera_apply_for(@user) { JobApplications::DispatchJob.perform_now }

    assert_enqueued_with(job: JobApplications::SendJob, args: [ oldest.id ])
  end

  test "skips users who are not enabled or already have a row sending" do
    other = users(:two)
    create_application(other)
    create_application(@user)
    create_application(@user, status: "sending")

    with_seera_apply_for(@user) { JobApplications::DispatchJob.perform_now }

    assert_no_enqueued_jobs only: JobApplications::SendJob
  end

  test "does nothing while the feature is dark" do
    create_application(@user)

    JobApplications::DispatchJob.perform_now

    assert_no_enqueued_jobs
  end

  test "is scheduled every 15 minutes" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    assert_equal({ "cron" => "*/15 * * * *", "class" => "JobApplications::DispatchJob", "queue" => "default" },
                 schedule["seera_apply_dispatch"])
  end
end
