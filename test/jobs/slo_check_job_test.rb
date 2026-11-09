require "test_helper"

class SloCheckJobTest < ActiveSupport::TestCase
  BREACH = { completed: 18, failed: 2, success_rate: 0.9, p50: 4.0, p95: 9.0 }.freeze

  setup do
    ServiceLevels.stubs(:sidekiq).returns(nil)
  end

  test "warns Sentry once per AI kind below its SLO, fingerprinted by day" do
    ServiceLevels.stubs(:ai_breaches).returns({ "cv_analyses" => BREACH })
    Sentry.expects(:capture_message).once.with do |message, **options|
      message == "SLO missed: cv_analyses success 90.0% < 98.0% over 24h" &&
        options[:level] == :warning &&
        options[:fingerprint] == [ "slo-ai-success", "cv_analyses", Date.current.iso8601 ] &&
        options[:extra] == { completed: 18, failed: 2, p50: 4.0, p95: 9.0 }
    end

    assert_equal [ "cv_analyses" ], SloCheckJob.perform_now[:ai_breaches]
  end

  test "sends nothing when every SLO holds" do
    ServiceLevels.stubs(:ai_breaches).returns({})
    Sentry.expects(:capture_message).never

    assert_equal({ ai_breaches: [], dead_grew: false }, SloCheckJob.perform_now)
  end

  test "warns when the dead set grew since the last run, and only then" do
    ServiceLevels.stubs(:ai_breaches).returns({})
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(store)
    ServiceLevels.stubs(:sidekiq).returns({ dead: 2 })

    Sentry.expects(:capture_message).never
    assert_not SloCheckJob.perform_now[:dead_grew], "the first run only records the count"
    assert_not SloCheckJob.perform_now[:dead_grew]

    ServiceLevels.stubs(:sidekiq).returns({ dead: 5 })
    Sentry.unstub(:capture_message)
    Sentry.expects(:capture_message).once.with do |message, **options|
      message == "Sidekiq dead jobs grew from 2 to 5" && options[:fingerprint] == [ "slo-dead-jobs", Date.current.iso8601 ]
    end
    assert SloCheckJob.perform_now[:dead_grew]
  end

  test "is scheduled hourly" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    assert_equal({ "cron" => "5 * * * *", "class" => "SloCheckJob", "queue" => "default" }, schedule["slo_check"])
  end
end
