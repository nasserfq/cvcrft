require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::SendJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup { @user = users(:one) }

  def send_job(app) = with_seera_apply_for(@user) { JobApplications::SendJob.perform_now(app.id) }

  test "runs on the apply_browser queue" do
    assert_equal "apply_browser", JobApplications::SendJob.new.queue_name
  end

  test "a browser send holds the slot while Sender runs and releases it" do
    app = create_application(@user)
    JobApplications::BrowserSlot.expects(:acquire).returns("token")
    JobApplications::Sender.any_instance.expects(:call)
    JobApplications::BrowserSlot.expects(:release).with("token")

    send_job(app)
  end

  test "re-enqueues itself in a minute when the slot is busy" do
    app = create_application(@user)
    JobApplications::BrowserSlot.expects(:acquire).returns(nil)
    JobApplications::Sender.any_instance.expects(:call).never

    freeze_time do
      send_job(app)
      assert_enqueued_with(job: JobApplications::SendJob, args: [ app.id ], at: 1.minute.from_now)
    end
  end

  test "an email send needs no slot" do
    app = create_application(@user, channel: "email")
    JobApplications::BrowserSlot.expects(:acquire).never
    JobApplications::Sender.any_instance.expects(:call)

    send_job(app)
  end

  test "is a no-op on a row that is not queued and when the gate is off" do
    JobApplications::Sender.any_instance.expects(:call).never
    JobApplications::BrowserSlot.expects(:acquire).never

    send_job(create_application(@user, status: "sent"))
    send_job(create_application(@user, status: "needs_approval"))
    JobApplications::SendJob.perform_now(create_application(@user).id)
    JobApplications::SendJob.perform_now(0)
  end
end
