require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::PrepareJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  PACK = { questions: [ { "id" => "q1", "label" => "Why us?", "type" => "textarea", "required" => true } ],
           answers: { "q1" => "Mission." }, missing: [], summary: "Product manager.", cover_letter: nil }.freeze

  setup do
    @user = users(:one)
    create_profile(@user)
  end

  def prepare(app) = with_seera_apply_for(@user) { JobApplications::PrepareJob.perform_now(app.id) }

  test "builds the pack and routes it" do
    app = create_application(@user, status: "preparing")
    JobApplications::PrepareJob.any_instance.expects(:build_pack).with { |a| a.id == app.id }.returns(PACK)

    prepare(app)

    app.reload
    assert_equal [ "needs_approval", "Product manager.", { "q1" => "Mission." } ], [ app.status, app.summary, app.answers ]
  end

  test "a manual row keeps its pack and ends unsupported" do
    app = create_application(@user, status: "preparing", channel: "manual")
    JobApplications::PrepareJob.any_instance.expects(:build_pack).returns(PACK)

    prepare(app)

    assert_equal %w[failed_fallback unsupported], app.reload.values_at(:status, :error_code)
  end

  test "stays preparing between attempts and ends prepare_failed once retries are used up" do
    app = create_application(@user, status: "preparing")
    JobApplications::PrepareJob.any_instance.stubs(:build_pack).raises(RuntimeError, "PDF failed")
    Sentry.stubs(:capture_exception)

    with_seera_apply_for(@user) do
      JobApplications::PrepareJob.perform_now(app.id)
      assert_equal "preparing", app.reload.status

      perform_enqueued_jobs
      perform_enqueued_jobs
    end

    assert_equal %w[failed_fallback prepare_failed], app.reload.values_at(:status, :error_code)
  end

  test "an open AI breaker is retried without Sentry" do
    app = create_application(@user, status: "preparing")
    JobApplications::PrepareJob.any_instance.stubs(:build_pack).raises(AiCircuit::OpenError)
    Sentry.expects(:capture_exception).never

    with_seera_apply_for(@user) do
      assert_enqueued_jobs(1, only: JobApplications::PrepareJob) { JobApplications::PrepareJob.perform_now(app.id) }
    end

    assert_equal "preparing", app.reload.status
  end

  test "is a no-op on a row past preparing and when the gate is off" do
    JobApplications::PrepareJob.any_instance.expects(:build_pack).never
    done = create_application(@user, status: "sent")
    prepare(done)

    waiting = create_application(@user, status: "preparing")
    JobApplications::PrepareJob.perform_now(waiting.id)

    assert_equal "sent", done.reload.status
    assert_equal "preparing", waiting.reload.status
  end
end
