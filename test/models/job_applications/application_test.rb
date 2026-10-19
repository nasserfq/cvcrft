require "test_helper"
require_relative "../../support/auto_apply_helper"

class JobApplications::ApplicationTest < ActiveSupport::TestCase
  include AutoApplyHelper

  test "status must be known" do
    app = JobApplications::Application.new(user: users(:one), posting: create_posting, status: "done")
    assert_has_errors app, :status
  end

  test "next_for takes the user's oldest approved application" do
    newer = create_application(users(:one))
    older = create_application(users(:one))
    older.update_columns(created_at: 1.hour.ago)
    create_application(users(:one), status: "queued").update_columns(created_at: 2.hours.ago)
    create_application(users(:two)).update_columns(created_at: 3.hours.ago)

    JobApplications::Application.transaction do
      assert_equal older, JobApplications::Application.next_for(users(:one))
    end
    assert newer.persisted?
  end

  test "requeue_stale! returns abandoned in_progress applications" do
    stale = create_application(users(:one), status: "in_progress", started_at: 31.minutes.ago)
    live = create_application(users(:one), status: "in_progress", started_at: 5.minutes.ago)

    JobApplications::Application.requeue_stale!(users(:one))

    assert_equal "approved", stale.reload.status
    assert_equal "in_progress", live.reload.status
  end

  test "transitions" do
    app = JobApplications::Application.new(status: "in_progress")
    assert app.can_transition_to?("submitted")
    assert_not app.can_transition_to?("approved")
    assert JobApplications::Application.new(status: "needs_user").can_transition_to?("submitted")
    assert_not JobApplications::Application.new(status: "submitted").can_transition_to?("failed")
  end

  test "AiUsage.bump! counts atomically per user and day" do
    JobApplications::AiUsage.bump!(users(:one), :scores, 5)
    JobApplications::AiUsage.bump!(users(:one), :scores)
    JobApplications::AiUsage.bump!(users(:one), :answers)

    usage = JobApplications::AiUsage.for(users(:one))
    assert_equal [ 6, 1 ], [ usage.scores, usage.answers ]
    assert_equal 1, JobApplications::AiUsage.where(user: users(:one)).count
    assert_equal JobApplications::DAILY_SCORE_LIMIT - 6, JobApplications::AiUsage.remaining(users(:one), :scores, JobApplications::DAILY_SCORE_LIMIT)
    assert_raises(ArgumentError) { JobApplications::AiUsage.bump!(users(:one), :tokens) }
  end
end
