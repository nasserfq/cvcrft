require "test_helper"
require_relative "../../../support/seera_apply_helper"
require_relative "fake_page"

class JobApplications::Submitters::GreenhouseTest < ActiveSupport::TestCase
  include SeeraApplyHelper
  include SubmitterFakes

  Greenhouse = JobApplications::Submitters::Greenhouse

  QUESTIONS = [
    { "id" => "first_name", "label" => "First Name", "type" => "text", "options" => [], "required" => true, "section" => "main" },
    { "id" => "email", "label" => "Email", "type" => "email", "options" => [], "required" => true, "section" => "main" },
    { "id" => "resume", "label" => "Resume/CV", "type" => "file", "options" => [], "required" => true, "section" => "main" },
    { "id" => "cover_letter", "label" => "Cover Letter", "type" => "file", "options" => [], "required" => false, "section" => "main" },
    { "id" => "question_30002", "label" => "Authorized?", "type" => "select", "options" => %w[Yes No], "required" => true, "section" => "main" },
    { "id" => "question_30003[]", "label" => "Tools", "type" => "checkbox", "options" => %w[Jira SQL], "required" => false, "section" => "main" },
    { "id" => "gender", "label" => "Gender", "type" => "select", "options" => %w[Male Female], "required" => false, "section" => "eeo" }
  ].freeze
  ANSWERS = { "first_name" => "Sara", "email" => "sara@example.com", "resume" => "cv_pdf",
              "question_30002" => "Yes", "question_30003[]" => [ "Jira", "SQL" ] }.freeze
  REQUIRED = [ { "id" => "first_name", "name" => "first_name" }, { "id" => "email", "name" => "email" },
               { "id" => "resume", "name" => "resume" }, { "id" => "question_30002", "name" => "question_30002" } ].freeze
  SUBMIT = Greenhouse.new(nil, cv_pdf: nil).send(:submit_selector)

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @app = sending_application(ats: "greenhouse", questions: QUESTIONS, answers: ANSWERS, posting_attrs: { external_id: "4567" })
  end

  teardown { ENV.delete("SEERA_APPLY_DRY_RUN") }

  def page(**options)
    FakePage.new(required: REQUIRED, after_submit: { url: "https://job-boards.greenhouse.io/acme/jobs/4567/confirmation", text: "Thank you for applying." },
                 **options)
  end

  test "questions come from the job board API, with EEO questions in their own section" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(file_fixture("ats_forms/greenhouse_questions.json").read)
    Net::HTTP.expects(:start).with("boards-api.greenhouse.io", 443, has_entries(use_ssl: true, open_timeout: 5, read_timeout: 20)).returns(response)

    questions = Greenhouse.questions(@app.posting)
    by_id = questions.index_by { |q| q["id"] }

    assert_equal %w[first_name last_name email phone resume cover_letter question_30001 question_30002 question_30003[] question_30004
                    candidate_location gender demographic_9001], questions.map { |q| q["id"] }
    assert_equal({ "id" => "resume", "label" => "Resume/CV", "type" => "file", "options" => [], "required" => true, "section" => "main" }, by_id["resume"])
    assert_equal [ "email", "tel" ], [ by_id["email"]["type"], by_id["phone"]["type"] ]
    assert_equal [ "select", %w[Yes No], true ], by_id["question_30002"].values_at("type", "options", "required")
    assert_equal [ "checkbox", %w[Jira Figma SQL] ], by_id["question_30003[]"].values_at("type", "options")
    assert_equal "main", by_id["candidate_location"]["section"]
    assert_equal [ "eeo", "eeo" ], [ by_id["gender"]["section"], by_id["demographic_9001"]["section"] ]
    assert_equal [ "checkbox", [ "Arab", "Prefer not to say" ] ], by_id["demographic_9001"].values_at("type", "options")
  end

  test "an HTTP error raises QuestionsError" do
    Net::HTTP.stubs(:start).returns(Net::HTTPNotFound.new("1.1", "404", "Not Found"))

    assert_raises(JobApplications::Submitters::Base::QuestionsError) { Greenhouse.questions(@app.posting) }
  end

  test "fills every answered field, attaches the CV, clicks Submit once and returns the proof" do
    fake = page
    result = submitter_for(@app, fake).call

    assert result.sent?
    assert_equal "https://job-boards.greenhouse.io/embed/job_app?for=acme&token=4567", fake.logged(:go_to).sole.last
    assert_includes fake.log, [ :set, '[id="first_name"]', "Sara" ]
    assert_includes fake.log, [ :set, '[id="email"]', "sara@example.com" ]
    assert_includes fake.log, [ :type, '[id="question_30002"]', "Yes", :enter ]
    assert_includes fake.log, [ :check, "question_30003[]", %w[Jira SQL] ]
    file = fake.logged(:file).sole
    assert_equal [ 'input[type="file"][id="resume"]', "cv.pdf", "%PDF-1.4 tailored" ], file.drop(1)
    assert_equal [ [ :click, '[id="question_30002"]' ], [ :click, SUBMIT ] ], fake.logged(:click)
    assert_not fake.log.any? { |entry| entry[1].to_s.include?("gender") }, "an unanswered EEO question is left blank"
    assert_equal [ "jpeg-bytes", "image/jpeg" ], [ result.proof_bytes, result.proof_type ]
    assert_equal "https://job-boards.greenhouse.io/acme/jobs/4567/confirmation", result.confirmation[:url]
    assert_equal({ format: "jpeg", quality: 60, full: true, encoding: :binary }, fake.logged(:screenshot).sole.last)
    assert_not_nil @app.reload.submit_clicked_at
  end

  test "a required checkbox group counts as answered by its name" do
    questions = QUESTIONS.map { |q| q["id"] == "question_30003[]" ? q.merge("required" => true) : q }
    @app.update!(questions:)
    fake = page(required: REQUIRED + [ { "id" => "question_30003[]_11", "name" => "question_30003[]", "type" => "checkbox" } ])

    assert submitter_for(@app, fake).call.sent?
  end

  test "a required cover letter is uploaded as a text file" do
    questions = QUESTIONS.map { |q| q["id"] == "cover_letter" ? q.merge("required" => true) : q }
    @app.update!(questions:, answers: ANSWERS.merge("cover_letter" => "Dear team"))
    fake = page(required: REQUIRED + [ { "id" => "cover_letter", "name" => "cover_letter" } ])

    assert submitter_for(@app, fake).call.sent?
    assert_includes fake.logged(:file), [ :file, 'input[type="file"][id="cover_letter"]', "Cover letter.txt", "Dear team" ]
  end

  test "a required field with no answer stops before anything is filled or clicked" do
    fake = page(required: REQUIRED + [ { "id" => "question_99999", "name" => "" } ])

    result = submitter_for(@app, fake).call

    assert_equal "unknown_field", result.error_code
    assert_empty fake.logged(:click)
    assert_empty fake.logged(:set)
    assert_nil @app.reload.submit_clicked_at
  end

  test "a required question whose field is gone from the page stops before Submit" do
    fake = page(missing: [ '[id="first_name"]' ])

    assert_equal "unknown_field", submitter_for(@app, fake).call.error_code
    assert_not_includes fake.logged(:click), [ :click, SUBMIT ]
  end

  test "a visible captcha before Submit is a captcha fallback" do
    fake = page(captcha: true)

    assert_equal "captcha", submitter_for(@app, fake).call.error_code
    assert_empty fake.logged(:click)
  end

  test "a captcha after Submit is a captcha fallback" do
    fake = page(after_submit: { captcha: true })

    assert_equal "captcha", submitter_for(@app, fake).call.error_code
    assert_not_nil @app.reload.submit_clicked_at
  end

  test "no confirmation in time is a timeout fallback" do
    fake = page(after_submit: { url: "https://job-boards.greenhouse.io/embed/job_app?for=acme&token=4567", text: "Please fix the errors" })

    assert_equal "timeout", submitter_for(@app, fake).call.error_code
  end

  test "a page without the form is a no_form fallback" do
    fake = page(missing: [ "form#application-form, form#application_form, form" ])

    assert_equal "no_form", submitter_for(@app, fake).call.error_code
  end

  test "a browser timeout before the click raises Retryable" do
    fake = page(on_go_to: -> { raise Ferrum::TimeoutError })

    assert_raises(JobApplications::Submitters::Retryable) { submitter_for(@app, fake).call }
    assert_nil @app.reload.submit_clicked_at
  end

  test "a dead browser after the click is not retryable" do
    fake = page(on_click: ->(selector) { raise Ferrum::DeadBrowserError if selector == SUBMIT })

    assert_raises(Ferrum::DeadBrowserError) { submitter_for(@app, fake).call }
    assert_not_nil @app.reload.submit_clicked_at
  end

  test "a row that is no longer sending is never clicked" do
    @app.update_columns(status: "queued")
    fake = page

    assert_raises(JobApplications::Submitters::Retryable) { submitter_for(@app, fake).call }
    assert_not_includes fake.logged(:click), [ :click, SUBMIT ]
  end

  test "dry run fills and screenshots but never clicks Submit" do
    ENV["SEERA_APPLY_DRY_RUN"] = "true"
    fake = page

    result = submitter_for(@app, fake).call

    assert_equal "dry_run", result.error_code
    assert_equal "jpeg-bytes", result.proof_bytes
    assert_includes fake.log, [ :set, '[id="first_name"]', "Sara" ]
    assert_not_includes fake.logged(:click), [ :click, SUBMIT ]
    assert_nil @app.reload.submit_clicked_at
  end

  test "requests stay on Greenhouse, its uploads and reCAPTCHA" do
    allow = Greenhouse.allowlist

    assert(allow.any? { |p| p.match?("https://job-boards.greenhouse.io/embed/job_app?for=acme") })
    assert(allow.any? { |p| p.match?("https://job-boards.cdn.greenhouse.io/assets/app.js") })
    assert(allow.any? { |p| p.match?("https://www.google.com/recaptcha/api2/anchor") })
    assert(allow.none? { |p| p.match?("https://www.google.com/search?q=x") })
    assert(allow.none? { |p| p.match?("https://greenhouse.io.evil.example/") })
    assert(allow.none? { |p| p.match?("https://evilgreenhouse.io/") })
  end
end
