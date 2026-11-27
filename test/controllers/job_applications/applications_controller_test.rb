require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::ApplicationsControllerTest < ActionDispatch::IntegrationTest
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  QUESTIONS = [
    { "id" => "q_notice", "label" => "Notice period?", "type" => "text", "required" => true },
    { "id" => "q_tools", "label" => "Tools", "type" => "checkbox", "options" => %w[Figma Jira], "required" => true },
    { "id" => "q_city", "label" => "City", "type" => "text", "required" => false }
  ].freeze

  setup do
    @user = users(:one)
    sign_in @user
    ENV["SEERA_APPLY_TESTERS"] = @user.email
    create_profile(@user)
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  test "approve queues the application and sends it now" do
    app = create_application(@user, status: "needs_approval", approval_required: true)

    assert_enqueued_with(job: JobApplications::SendJob, args: [ app.id ]) do
      patch approve_my_jobs_application_url(app, locale: "en")
    end

    assert_redirected_to my_jobs_root_path
    assert_equal I18n.t("seera_apply.flash.approved", locale: :en), flash[:notice]
    assert_equal "queued", app.reload.status
    assert app.approved_at
  end

  test "approving twice says it already moved" do
    app = create_application(@user, status: "queued")

    assert_no_enqueued_jobs { patch approve_my_jobs_application_url(app, locale: "en") }

    assert_equal I18n.t("seera_apply.flash.stale", locale: :en), flash[:alert]
  end

  test "skip ends the application" do
    app = create_application(@user, status: "needs_answer", missing: [ "q_notice" ], questions: QUESTIONS)

    patch skip_my_jobs_application_url(app)

    assert_equal "skipped", app.reload.status
  end

  test "answer takes only the missing questions and moves on once all are answered" do
    app = create_application(@user, status: "needs_answer", questions: QUESTIONS, missing: %w[q_notice q_tools],
                                    answers: { "q_city" => "Riyadh" })

    patch answer_my_jobs_application_url(app), params: { answers: { q_notice: "One month", q_tools: [ "", "Figma", "Jira" ],
                                                                    q_city: "Jeddah", q_other: "x" } }

    app.reload
    assert_equal "needs_approval", app.status
    assert_equal({ "q_city" => "Riyadh", "q_notice" => "One month", "q_tools" => %w[Figma Jira] }, app.answers)
    assert_empty app.missing
  end

  test "answer with only ids that are not missing changes nothing" do
    app = create_application(@user, status: "needs_answer", questions: QUESTIONS, missing: [ "q_notice" ])

    patch answer_my_jobs_application_url(app, locale: "en"), params: { answers: { q_city: "Jeddah", q_other: "x" } }

    app.reload
    assert_equal "needs_answer", app.status
    assert_equal({}, app.answers)
    assert_equal I18n.t("seera_apply.flash.stale", locale: :en), flash[:alert]
  end

  test "another user's application is a 404" do
    other = create_application(users(:two), status: "needs_approval")
    add_cv_pdf(other)

    patch approve_my_jobs_application_url(other)
    assert_response :not_found
    sign_in @user
    get cv_my_jobs_application_url(other)
    assert_response :not_found
    assert_equal "needs_approval", other.reload.status
  end

  test "cv sends the PDF inline" do
    app = create_application(@user)
    add_cv_pdf(app, "%PDF-1.4 mine")

    get cv_my_jobs_application_url(app)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline/, response.headers["Content-Disposition"])
    assert_equal "%PDF-1.4 mine", response.body
  end

  test "proof sends the screenshot, and a sent email as plain text" do
    shot = create_application(@user, status: "sent")
    JobApplications::Document.store!(shot, kind: "proof", data: "\xFF\xD8jpeg", content_type: "image/jpeg", filename: "proof.jpg")
    mail = create_application(@user, status: "sent")
    JobApplications::Document.store!(mail, kind: "proof", data: "Subject: Application", content_type: "message/rfc822", filename: "proof.eml")

    get proof_my_jobs_application_url(shot)
    assert_equal "image/jpeg", response.media_type
    assert_equal "\xFF\xD8jpeg".b, response.body.b

    get proof_my_jobs_application_url(mail)
    assert_equal "text/plain", response.media_type
    assert_equal "Subject: Application", response.body
  end

  test "a missing document is a 404" do
    app = create_application(@user)

    get proof_my_jobs_application_url(app)

    assert_response :not_found
  end
end
