require "test_helper"

# The production /sidekiq mount goes through SidekiqWebAuth; routes in the test
# env take the unprotected branch, so the auth is exercised directly here.
class SidekiqWebAuthTest < ActiveSupport::TestCase
  setup do
    @auth = SidekiqWebAuth.new(username: "admin", password: "s3cret")
    inner = ->(_env) { [ 200, { "content-type" => "text/plain" }, [ "dashboard" ] ] }
    @app = Rack::MockRequest.new(@auth.wrap(inner))
  end

  test "valid? accepts only the exact credentials" do
    assert @auth.valid?("admin", "s3cret")
    assert_not @auth.valid?("admin", "wrong")
    assert_not @auth.valid?("root", "s3cret")
    assert_not @auth.valid?(nil, nil)
  end

  test "rejects a request without credentials" do
    response = @app.get("/")

    assert_equal 401, response.status
    assert_match(/Basic realm="Sidekiq"/, response.headers["www-authenticate"])
  end

  test "rejects wrong credentials" do
    response = @app.get("/", "HTTP_AUTHORIZATION" => basic("admin", "nope"))

    assert_equal 401, response.status
    assert_not_includes response.body, "dashboard"
  end

  test "passes the right credentials through to the dashboard" do
    response = @app.get("/", "HTTP_AUTHORIZATION" => basic("admin", "s3cret"))

    assert_equal 200, response.status
    assert_equal "dashboard", response.body
  end

  test "from_env uses the admin panel's credentials" do
    with_env("ADMIN_USERNAME" => "ops", "ADMIN_PASSWORD" => "pw") do
      assert SidekiqWebAuth.from_env.valid?("ops", "pw")
    end
  end

  test "from_env without ADMIN_PASSWORD fails closed" do
    with_env("ADMIN_USERNAME" => nil, "ADMIN_PASSWORD" => nil) do
      auth = SidekiqWebAuth.from_env
      assert_not auth.valid?("admin", "")
      assert_not auth.valid?("admin", "admin")
    end
  end

  private

  def basic(username, password)
    ActionController::HttpAuthentication::Basic.encode_credentials(username, password)
  end

  def with_env(vars)
    saved = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| ENV[key] = value }
  end
end
