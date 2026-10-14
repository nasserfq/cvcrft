require "test_helper"

class Coach::ChatsControllerTest < ActionDispatch::IntegrationTest
  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @user = users(:one)
    sign_in @user
    ENV["COACH_TESTERS"] = @user.email
    @chat = Coach::Chat.create!(user: @user, path: "scratch")
  end

  teardown do
    ENV.delete("COACH_TESTERS")
  end

  test "is hidden when the coach is off" do
    ENV.delete("COACH_TESTERS")

    # A 404 doesn't write the session, so sign in again before each request.
    get coach_root_url
    assert_response :not_found
    sign_in @user
    get coach_chat_url(@chat)
    assert_response :not_found
    sign_in @user
    post message_coach_chat_url(@chat), params: { content: "Hi" }, as: :json
    assert_response :not_found
  end

  test "testers see the start screen" do
    get coach_root_url
    assert_response :success
    assert_select "form[action='#{coach_chats_path}']", 2
  end

  test "signed-out visitors are sent to sign in" do
    sign_out @user

    get coach_root_url
    assert_redirected_to login_path(return_to: "/coach")
  end

  test "create starts a chat on the chosen path" do
    assert_difference -> { Coach::Chat.count } do
      post coach_chats_url, params: { path: "import" }
    end
    chat = Coach::Chat.order(:id).last
    assert_equal [ @user, "import" ], [ chat.user, chat.path ]
    assert_redirected_to coach_chat_path(chat)
  end

  test "show renders the chat" do
    @chat.messages.create!(role: "user", content: "Hi")

    get coach_chat_url(@chat)
    assert_response :success
    assert_select "#coach-chat-root[data-chat-id='#{@chat.id}']"
  end

  test "another user's chat is not found" do
    other = Coach::Chat.create!(user: users(:two), path: "scratch")

    get coach_chat_url(other)
    assert_response :not_found
    sign_in @user # the 404 doesn't write the session
    post message_coach_chat_url(other), params: { content: "Hi" }, as: :json
    assert_response :not_found
  end

  test "message saves the user's text and queues a turn" do
    assert_enqueued_with(job: Coach::TurnJob, args: [ @chat.id ], queue: "coach") do
      post message_coach_chat_url(@chat), params: { content: "I was a cashier" }, as: :json
    end
    assert_response :accepted
    assert_equal "I was a cashier", @chat.messages.last.content
  end

  test "a blank message is rejected" do
    assert_no_enqueued_jobs do
      post message_coach_chat_url(@chat), params: { content: " " }, as: :json
    end
    assert_response :unprocessable_entity
  end
end
