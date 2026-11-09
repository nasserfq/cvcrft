require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "200 when Postgres and Redis answer" do
    HealthProbe.stubs(:redis_ok?).returns(true)

    get "/up"

    assert_response :ok
    assert_equal "ok", json_response["status"]
    assert_equal({ "database" => "ok", "redis" => "ok" }, json_response["checks"])
    assert_equal [], json_response["failing"]
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "503 naming Redis when it is down" do
    HealthProbe.stubs(:redis_ok?).returns(false)

    get "/up"

    assert_response :service_unavailable
    assert_equal "error", json_response["status"]
    assert_equal [ "redis" ], json_response["failing"]
  end

  test "503 naming the database when it is down" do
    HealthProbe.stubs(:redis_ok?).returns(true)
    HealthProbe.stubs(:database_ok?).returns(false)

    get "/up"

    assert_response :service_unavailable
    assert_equal [ "database" ], json_response["failing"]
  end

  test "sets no cookie, even with a locale param, and serves non-browser agents" do
    HealthProbe.stubs(:redis_ok?).returns(true)

    get "/up?locale=en", headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 6.1) MSIE 9.0" }

    assert_response :ok
    assert_nil response.headers["Set-Cookie"]
  end
end

class HealthProbeTest < ActiveSupport::TestCase
  test "database answers SELECT 1" do
    assert HealthProbe.database_ok?
  end

  test "database errors are a failed check, not an exception" do
    ActiveRecord::Base.connection_pool.stubs(:with_connection).raises(ActiveRecord::ConnectionNotEstablished)

    assert_not HealthProbe.database_ok?
  end

  test "an unreachable Redis fails fast" do
    pool = RedisClient.config(url: "redis://127.0.0.1:1", connect_timeout: HealthProbe::TIMEOUT, reconnect_attempts: 0).new_pool(size: 1)
    HealthProbe.stubs(:redis_pool).returns(pool)

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_not HealthProbe.redis_ok?
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
  end

  test "its Redis client gives up within the timeout and never retries" do
    config = HealthProbe.redis_pool.config

    assert_equal HealthProbe::TIMEOUT, config.connect_timeout
    assert_equal HealthProbe::TIMEOUT, config.read_timeout
    assert_not config.retry_connecting?(0, RedisClient::CannotConnectError.new)
  end
end
