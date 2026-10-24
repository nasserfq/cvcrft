require "test_helper"

class SentryTracesSamplerTest < ActiveSupport::TestCase
  test "skips the health check" do
    assert_equal 0.0, SentryTracesSampler.call(env: { "PATH_INFO" => "/up" })
  end

  test "skips bin/load-test requests" do
    assert_equal 0.0, SentryTracesSampler.call(env: { "PATH_INFO" => "/", "HTTP_USER_AGENT" => "oha/1.4.5" })
  end

  test "follows the browser's sampling decision" do
    assert_equal 0.0, SentryTracesSampler.call(parent_sampled: false, env: { "PATH_INFO" => "/" })
    assert_equal 1.0, SentryTracesSampler.call(parent_sampled: true, env: { "PATH_INFO" => "/" })
  end

  test "traces pages and jobs at the configured rate" do
    with_env("SENTRY_TRACES_SAMPLE_RATE" => nil) do
      assert_equal 1.0, SentryTracesSampler.call(env: { "PATH_INFO" => "/", "HTTP_USER_AGENT" => "Mozilla/5.0" })
      assert_equal 1.0, SentryTracesSampler.call({})
    end
    with_env("SENTRY_TRACES_SAMPLE_RATE" => "0.5") do
      assert_equal 0.5, SentryTracesSampler.call(env: { "PATH_INFO" => "/" })
    end
  end

  private

  def with_env(vars)
    old = vars.keys.index_with { ENV[_1] }
    vars.each { ENV[_1] = _2 }
    yield
  ensure
    old.each { ENV[_1] = _2 }
  end
end
