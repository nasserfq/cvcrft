require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::ApplicationTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  test "transition! moves only from the given status" do
    app = create_application(@user, status: "preparing")

    assert app.transition!(from: "preparing", to: "queued")
    assert_equal "queued", app.status
    assert_not app.transition!(from: "preparing", to: "needs_approval")
    assert_equal "queued", app.reload.status
    assert_raises(ArgumentError) { app.transition!(from: "queued", to: "done") }
  end

  test "finish_pack! goes to needs_answer when a required answer is missing" do
    app = create_application(@user, status: "preparing")

    assert app.finish_pack!(questions: [ { "id" => "q1" } ], answers: {}, missing: [ "q1" ], summary: "Fit.")
    assert_equal "needs_answer", app.status
    assert_equal [ "q1" ], app.missing
    assert app.approval_required
  end

  test "finish_pack! asks for approval until three were sent, then queues" do
    app = create_application(@user, status: "preparing")
    assert app.finish_pack!(questions: [], answers: {}, missing: [], summary: "Fit.")
    assert_equal "needs_approval", app.status

    3.times { create_application(@user, status: "sent", sent_at: Time.current) }
    other = create_application(@user, status: "preparing")
    assert other.finish_pack!(questions: [], answers: {}, missing: [], summary: "Fit.", cover_letter: "Dear team")
    assert_equal "queued", other.status
    assert_not other.approval_required
    assert_equal "Dear team", other.cover_letter
  end

  test "finish_pack! does nothing on a row that is no longer preparing" do
    app = create_application(@user, status: "skipped")

    assert_not app.finish_pack!(questions: [], answers: {}, missing: [], summary: "Fit.")
    assert_equal "skipped", app.reload.status
  end

  test "answer! takes only missing ids and moves on once all are answered" do
    app = create_application(@user, status: "needs_answer", approval_required: true, missing: %w[q1 q2],
                                    answers: { "q0" => "x" }, questions: [ { "id" => "q1", "label" => "Years?" }, { "id" => "q2", "label" => "Why?" } ])

    assert app.answer!("q1" => "5", "other" => "nope")
    assert_equal "needs_answer", app.status
    assert_equal({ "q0" => "x", "q1" => "5" }, app.answers)
    assert_equal [ "q2" ], app.missing

    assert app.answer!("q2" => "Because")
    assert_equal "needs_approval", app.status
    assert_equal [], app.missing
  end

  test "answer! queues when approval is no longer needed and remembers non-sensitive answers" do
    create_profile(@user)
    3.times { create_application(@user, status: "sent") }
    app = create_application(@user, status: "needs_answer", missing: %w[q1 q2],
                                    questions: [ { "id" => "q1", "label" => "Years of SQL?", "type" => "text" },
                                                 { "id" => "q2", "label" => "Gender", "type" => "select" } ])
    JobApplications::Application.any_instance.stubs(:sensitive_label?).with("Years of SQL?").returns(false)
    JobApplications::Application.any_instance.stubs(:sensitive_label?).with("Gender").returns(true)

    assert app.answer!("q1" => "4", "q2" => "Female")

    assert_equal "queued", app.status
    saved = JobApplications::Profile.find_by!(user: @user).saved_answers
    assert_equal({ "years of sql" => "4" }, saved)
  end

  test "answer! refuses a row that isn't waiting for answers" do
    app = create_application(@user, status: "queued", missing: [ "q1" ])

    assert_not app.answer!("q1" => "x")
  end

  test "approve! queues and enqueues SendJob" do
    app = create_application(@user, status: "needs_approval")

    assert_enqueued_with(job: JobApplications::SendJob, args: [ app.id ]) { assert app.approve! }
    assert_equal "queued", app.status
    assert app.approved_at
    assert_no_enqueued_jobs { assert_not app.approve! }
  end

  test "skip! works from needs_approval, needs_answer and queued only" do
    %w[needs_approval needs_answer queued].each do |status|
      app = create_application(@user, status:)
      assert app.skip!, status
      assert_equal "skipped", app.status
    end
    %w[preparing sending sent failed_fallback].each do |status|
      assert_not create_application(@user, status:).skip!, status
    end
  end

  test "fallback! ends any unfinished row and never a finished one" do
    (JobApplications::Application::STATUSES - JobApplications::Application::TERMINAL).each do |status|
      app = create_application(@user, status:, hold: (status == "queued" ? "paused" : nil))
      assert app.fallback!("captcha"), status
      assert_equal [ "failed_fallback", "captcha", nil ], [ app.status, app.error_code, app.hold ]
    end
    JobApplications::Application::TERMINAL.each do |status|
      assert_not create_application(@user, status:).fallback!("captcha"), status
    end
    assert_raises(ArgumentError) { create_application(@user).fallback!("bogus") }
  end

  test "mark_submit_clicked! marks a sending row once" do
    app = create_application(@user, status: "sending")

    assert app.mark_submit_clicked!
    assert app.reload.submit_clicked_at
    assert_not app.mark_submit_clicked!
    assert_not create_application(@user, status: "queued").mark_submit_clicked!
  end

  test "fail_stale! handles each stale state" do
    cutoff = 30.minutes.ago
    preparing = create_application(@user, status: "preparing")
    preparing.update_column(:updated_at, 1.hour.ago)
    fresh = create_application(@user, status: "preparing")
    unclicked = create_application(@user, status: "sending", attempts: 1, claimed_at: 1.hour.ago)
    used_up = create_application(@user, status: "sending", attempts: 3, claimed_at: 1.hour.ago)
    clicked = create_application(@user, status: "sending", attempts: 1, claimed_at: 1.hour.ago, submit_clicked_at: 1.hour.ago)
    uncharged = create_application(@user, status: "sent", sent_at: 1.hour.ago)

    assert_equal 5, JobApplications::Application.fail_stale!(older_than: cutoff)

    assert_equal %w[failed_fallback prepare_failed], [ preparing.reload.status, preparing.error_code ]
    assert_equal "preparing", fresh.reload.status
    assert_equal "queued", unclicked.reload.status
    assert_nil unclicked.claimed_at
    assert_equal %w[failed_fallback timeout], [ used_up.reload.status, used_up.error_code ]
    assert_equal %w[failed_fallback unconfirmed], [ clicked.reload.status, clicked.error_code ]
    assert_equal "free", uncharged.reload.charge
    assert_equal 1, @user.reload.job_applications_count

    assert_equal 0, JobApplications::Application.fail_stale!(older_than: cutoff)
    assert_equal 1, @user.reload.job_applications_count
  end

  test "purge_old! drops old documents and old answers of finished rows only" do
    old = create_application(@user, status: "sent", answers: { "q" => "a" }, cover_letter: "Dear")
    add_cv_pdf(old)
    old.update_column(:updated_at, 100.days.ago)
    older = create_application(@user, status: "skipped", answers: { "q" => "a" }, cover_letter: "Dear")
    older.update_column(:updated_at, 200.days.ago)
    waiting = create_application(@user, status: "needs_answer", answers: { "q" => "a" })
    add_cv_pdf(waiting)
    waiting.update_column(:updated_at, 200.days.ago)

    JobApplications::Application.purge_old!

    assert_not old.documents.exists?
    assert_equal({ "q" => "a" }, old.reload.answers)
    assert_equal [ {}, nil ], [ older.reload.answers, older.cover_letter ]
    assert waiting.documents.exists?
    assert_equal({ "q" => "a" }, waiting.reload.answers)
  end

  test "one application per user and posting" do
    app = create_application(@user)

    assert_raises(ActiveRecord::RecordInvalid) { create_application(@user, posting: app.posting) }
  end
end
