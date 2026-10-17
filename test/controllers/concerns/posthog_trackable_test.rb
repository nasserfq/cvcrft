require "test_helper"

class PosthogTrackableTest < ActiveSupport::TestCase
  class FakeController
    include PosthogTrackable

    attr_reader :cookies, :current_user, :request, :logged

    def initialize(user, consent:)
      @current_user = user
      @cookies = { analytics_consent: consent ? "granted" : nil }
      @request = Struct.new(:original_url, :referrer, :user_agent, :remote_ip).new("http://test/", nil, "test", "127.0.0.1")
    end

    public :track_event, :identify_user
  end

  test "track_event sends the event through the PostHog client" do
    user = users(:one)
    PostHog.expects(:capture).with { |attrs| attrs[:event] == "resume_created" && attrs[:distinct_id] == user.id.to_s }
    Rails.logger.expects(:error).never

    FakeController.new(user, consent: true).track_event("resume_created")
  end

  test "identify_user sends the user through the PostHog client" do
    user = users(:one)
    PostHog.expects(:identify).with { |attrs| attrs[:distinct_id] == user.id.to_s }
    Rails.logger.expects(:error).never

    FakeController.new(user, consent: true).identify_user(user)
  end

  test "nothing is sent without analytics consent" do
    PostHog.expects(:capture).never

    FakeController.new(users(:one), consent: false).track_event("resume_created")
  end
end
