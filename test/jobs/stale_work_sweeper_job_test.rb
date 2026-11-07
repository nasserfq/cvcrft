require "test_helper"

class StaleWorkSweeperJobTest < ActiveSupport::TestCase
  test "fails stale work on every model that can and reports the counts" do
    stale = create_test_cv_generation(users(:test_user))
    stale.update_column(:updated_at, 1.hour.ago)
    fresh = create_test_cv_generation(users(:test_user))

    counts = StaleWorkSweeperJob.perform_now

    assert_equal 1, counts["cv_generations"]
    assert_equal "failed", stale.reload.status
    assert_equal "processing", fresh.reload.status
  end

  test "passes the 30 minute cutoff to each model" do
    freeze_time do
      StaleWorkSweeperJob::MODEL_NAMES.each do |name|
        model = name.constantize
        next unless model.respond_to?(:fail_stale!)

        model.expects(:fail_stale!).with(older_than: 30.minutes.ago).returns(0)
      end

      StaleWorkSweeperJob.perform_now
    end
  end

  test "skips a model that has no fail_stale! yet" do
    stub_const(StaleWorkSweeperJob, :MODEL_NAMES, %w[CvGeneration OtpVerification]) do
      assert_equal [ "cv_generations" ], StaleWorkSweeperJob.perform_now.keys
    end
  end

  test "is scheduled every 10 minutes" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    assert_equal({ "cron" => "*/10 * * * *", "class" => "StaleWorkSweeperJob", "queue" => "default" },
                 schedule["stale_work_sweeper"])
  end
end
