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
      post coach_chats_url, params: { path: "scratch" }
    end
    chat = Coach::Chat.order(:id).last
    assert_equal [ @user, "scratch" ], [ chat.user, chat.path ]
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

  test "the import card lists only the user's own resumes" do
    stub_pdf_generation
    mine = ResumeBuilder::PublicApi.create_from_draft(@user, "complete_name" => "Sara Ali", "email" => "sara@example.com")
    theirs = ResumeBuilder::PublicApi.create_from_draft(users(:two), "complete_name" => "Someone Else", "email" => "else@example.com")

    get coach_root_url
    assert_select "select[name='resume_id'] option[value='#{mine.id}']"
    assert_select "select[name='resume_id'] option[value='#{theirs.id}']", 0
  end

  test "a PDF upload starts an import chat with its text and queues a turn" do
    CvPdfImportService.any_instance.stubs(:parse).returns(text: "Sara Ali\nCashier, Panda", language: "en")

    assert_enqueued_with(job: Coach::TurnJob, queue: "coach") do
      post coach_chats_url, params: { path: "import", pdf_file: fixture_file_upload("cv.pdf", "application/pdf") }
    end
    chat = Coach::Chat.order(:id).last
    assert_redirected_to coach_chat_path(chat)
    assert_equal [ "import", {} ], [ chat.path, chat.draft ]
    assert_equal [ [ "user", "Sara Ali\nCashier, Panda" ] ], chat.messages.map { |m| [ m.role, m.content ] }
  end

  test "a non-PDF upload is rejected" do
    assert_no_difference -> { Coach::Chat.count } do
      post coach_chats_url, params: { path: "import", pdf_file: fixture_file_upload("cv.pdf", "text/plain") }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", I18n.t("coach.import.not_pdf")
  end

  test "an upload over 10 MB is rejected" do
    ActionDispatch::Http::UploadedFile.any_instance.stubs(:size).returns(11.megabytes)

    assert_no_difference -> { Coach::Chat.count } do
      post coach_chats_url, params: { path: "import", pdf_file: fixture_file_upload("cv.pdf", "application/pdf") }
    end
    assert_response :unprocessable_entity
  end

  test "picking a Seera resume copies it into the draft" do
    stub_pdf_generation
    draft = { "complete_name" => "Sara Ali", "email" => "sara@example.com", "professional_summary" => "Cashier.",
              "professional_summary_english" => "Cashier (EN).",
              "work_experience" => [ { "job_title" => "Cashier", "company" => "Panda", "start_date" => "2019-01",
                                       "end_date" => nil, "is_current" => true, "responsibilities" => [ "Till" ] } ] }
    resume = ResumeBuilder::PublicApi.create_from_draft(@user, draft)

    assert_enqueued_with(job: Coach::TurnJob) do
      post coach_chats_url, params: { path: "import", resume_id: resume.id }
    end
    chat = Coach::Chat.order(:id).last
    assert_equal [ "Cashier.", "Cashier (EN)." ], chat.draft.values_at("professional_summary", "professional_summary_english")
    assert_equal [ "Till" ], chat.draft["work_experience"].sole["responsibilities"]
    assert_equal "user", chat.messages.sole.role
  end

  test "another user's resume is not found" do
    stub_pdf_generation
    resume = ResumeBuilder::PublicApi.create_from_draft(users(:two), "complete_name" => "Someone Else", "email" => "else@example.com")

    assert_no_difference -> { Coach::Chat.count } do
      post coach_chats_url, params: { path: "import", resume_id: resume.id }
    end
    assert_response :not_found
  end

  test "accept applies the proposal and removes it" do
    chat = import_chat_with_proposal

    post accept_coach_chat_url(chat), params: { proposal_id: "abcd1234" }, as: :json
    assert_response :ok
    chat.reload
    assert_equal "Retail cashier who keeps queues short.", chat.draft["professional_summary"]
    assert_empty chat.proposals
  end

  test "reject removes the proposal and leaves the draft alone" do
    chat = import_chat_with_proposal

    post reject_coach_chat_url(chat), params: { proposal_id: "abcd1234" }, as: :json
    assert_response :ok
    chat.reload
    assert_equal "I work hard.", chat.draft["professional_summary"]
    assert_empty chat.proposals
  end

  test "an unknown proposal is not found" do
    chat = import_chat_with_proposal

    post accept_coach_chat_url(chat), params: { proposal_id: "nope" }, as: :json
    assert_response :not_found
    assert_equal 1, chat.reload.proposals.size
  end

  test "another user's proposals can't be accepted or rejected" do
    chat = import_chat_with_proposal(users(:two))

    post accept_coach_chat_url(chat), params: { proposal_id: "abcd1234" }, as: :json
    assert_response :not_found
    sign_in @user # the 404 doesn't write the session
    post reject_coach_chat_url(chat), params: { proposal_id: "abcd1234" }, as: :json
    assert_response :not_found
    assert_equal [ "I work hard.", 1 ], [ chat.reload.draft["professional_summary"], chat.proposals.size ]
  end

  private

  def import_chat_with_proposal(user = @user)
    Coach::Chat.create!(
      user:, path: "import", draft: { "professional_summary" => "I work hard." },
      proposals: [ { "id" => "abcd1234", "section" => "professional_summary", "index" => nil, "field" => "professional_summary",
                     "before" => "I work hard.", "after" => "Retail cashier who keeps queues short." } ]
    )
  end
end
