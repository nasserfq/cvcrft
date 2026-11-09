require "test_helper"

class ServiceLevelsTest < ActiveSupport::TestCase
  setup do
    @user = users(:test_user)
    # Well after the fixtures were loaded, so only the rows a test makes count.
    travel_to 30.days.from_now
  end

  def analysis(status, took: 10.seconds, created: 1.hour.ago)
    row = CvAnalysis.create!(user: @user, original_filename: "cv.pdf", status: status)
    row.update_columns(created_at: created, updated_at: created + took)
    row
  end

  test "counts completed and failed work per window with success rate and percentiles" do
    analysis("completed", took: 10.seconds)
    analysis("completed", took: 20.seconds)
    analysis("completed", took: 30.seconds)
    analysis("failed")
    analysis("processing")
    analysis("completed", took: 99.seconds, created: 3.days.ago)

    work = ServiceLevels.ai_work

    day = work["24h"]["cv_analyses"]
    assert_equal 3, day[:completed]
    assert_equal 1, day[:failed]
    assert_in_delta 0.75, day[:success_rate]
    assert_equal 20.0, day[:p50]
    assert_in_delta 29.0, day[:p95], 0.01

    assert_equal 4, work["7d"]["cv_analyses"][:completed]
    assert_equal ServiceLevels::KINDS, work["24h"].keys
  end

  test "an idle kind has no success rate or timings" do
    stats = ServiceLevels.ai_work["24h"]["cv_imports"]

    assert_equal({ completed: 0, failed: 0, success_rate: nil, p50: nil, p95: nil }, stats)
  end

  test "legacy builder-export generations and cancelled ones do not count" do
    create_test_cv_generation(@user, status: "completed")
    create_test_cv_generation(@user, status: "completed", ai_model: "cv_builder")
    create_test_cv_generation(@user, status: "cancelled")

    stats = ServiceLevels.ai_work["24h"]["cv_generations"]

    assert_equal 1, stats[:completed]
    assert_equal 0, stats[:failed]
  end

  test "coach turns: replied, ended without reply, timed out, and still running" do
    chat = Coach::Chat.create!(user: @user, path: "scratch")
    message = ->(role, at) { chat.messages.create!(role: role, content: "x", created_at: at, updated_at: at) }

    message.call("user", 50.minutes.ago)
    message.call("assistant", 50.minutes.ago + 4.seconds)
    message.call("user", 40.minutes.ago).end_turn!
    message.call("user", 30.minutes.ago) # no reply, past the turn timeout
    message.call("user", 20.minutes.ago)
    message.call("assistant", 20.minutes.ago + 8.seconds)
    message.call("user", 30.seconds.ago) # still running

    stats = ServiceLevels.ai_work["24h"]["coach_turns"]

    assert_equal 2, stats[:completed]
    assert_equal 2, stats[:failed]
    assert_equal 6.0, stats[:p50]
  end

  test "ai_breaches needs enough finished work and a rate below target" do
    work = { "24h" => {
      "cv_analyses" => { completed: 19, failed: 1, success_rate: 0.95 },
      "cv_imports" => { completed: 10, failed: 1, success_rate: 10 / 11.0 },
      "ai_translations" => { completed: 98, failed: 2, success_rate: 0.98 },
      "linkedin_imports" => { completed: 0, failed: 0, success_rate: nil }
    } }

    assert_equal [ "cv_analyses" ], ServiceLevels.ai_breaches(work).keys
  end

  test "sidekiq stats, or nil when Redis is unreachable" do
    Sidekiq::Stats.stubs(:new).returns(stub(enqueued: 3, retry_size: 2, dead_size: 1, queues: { "default" => 3 }))
    assert_equal({ enqueued: 3, retry: 2, dead: 1, queues: { "default" => 3 } }, ServiceLevels.sidekiq)

    Sidekiq::Stats.stubs(:new).raises(RedisClient::CannotConnectError)
    assert_nil ServiceLevels.sidekiq
  end
end
