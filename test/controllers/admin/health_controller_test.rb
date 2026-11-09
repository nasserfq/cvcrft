require "test_helper"

class Admin::HealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    HealthProbe.stubs(:redis_ok?).returns(true)
    ServiceLevels.stubs(:sidekiq).returns({ enqueued: 4, retry: 1, dead: 2, queues: { "default" => 4 } })
  end

  test "needs the admin Basic auth" do
    integration_session.get "/admin/health"

    assert_equal 401, integration_session.response.status
  end

  test "shows the checks, every AI kind for both windows and the Sidekiq counts, and no user data" do
    analysis = CvAnalysis.create!(user: users(:test_user), original_filename: "private-cv.pdf", status: "failed")

    get "/admin/health"

    assert_response :success
    assert_select "[data-health-check=database]", "OK"
    assert_select "[data-health-check=redis]", "OK"
    assert_select "table", ServiceLevels::WINDOWS.size
    ServiceLevels::KINDS.each { |kind| assert_select "tr[data-kind=#{kind}]", 2 }
    assert_select "dd", "4"
    assert_select "a[href='/admin/health']"
    assert_no_match(/#{Regexp.escape(users(:test_user).email)}|private-cv/, response.body)
    assert analysis.persisted?
  end

  test "shows Redis down and Sidekiq unavailable" do
    HealthProbe.stubs(:redis_ok?).returns(false)
    ServiceLevels.stubs(:sidekiq).returns(nil)

    get "/admin/health"

    assert_response :success
    assert_select "[data-health-check=redis]", "Down"
    assert_match "Unavailable", response.body
  end
end
