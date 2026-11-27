require "test_helper"
require_relative "../../support/seera_apply_helper"

# Real headless Chrome through Ferrum on local copies of each ATS form
# (test/fixtures/files/ats_forms/<ats>_form.html, scripts taken out). Each
# form submits (GET) to <ats>_confirmation.html, so the confirmation URL
# carries what was filled. Skipped when no Chrome is found, except on CI.
class JobApplications::BrowserFillTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  Submitters = JobApplications::Submitters
  P = "8c1d2e3f-aaaa-4bbb-8ccc-00000000000".freeze
  FORMS = Rails.root.join("test/fixtures/files/ats_forms")

  setup do
    skip "no Chrome found" unless ENV["CI"] || chrome?
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
  end

  test "greenhouse" do
    filled = fill("greenhouse", questions_from("greenhouse_questions.json", Submitters::Greenhouse),
                  "first_name" => "Sara", "last_name" => "Ali", "email" => "sara@example.com", "phone" => "+966 500000000",
                  "resume" => "cv_pdf", "question_30001" => "https://www.linkedin.com/in/sara", "question_30002" => "Yes",
                  "question_30003[]" => %w[Jira SQL], "question_30004" => "Line one\nLine two")

    assert_equal [ "Sara", "Ali", "sara@example.com", "+966 500000000" ], filled.values_at("first_name", "last_name", "email", "phone")
    assert_equal [ "https://www.linkedin.com/in/sara", "Yes", %w[11 13] ], filled.values_at("question_30001", "question_30002", "question_30003[]")
    assert_equal "Line one\r\nLine two", filled["question_30004"]
    assert_equal "cv.pdf", filled["resume"]
    assert_equal "", filled["cover_letter"], "an optional cover letter is left out"
    assert_equal "", filled["gender"], "optional EEO questions stay blank"
  end

  test "ashby" do
    filled = fill("ashby", questions_from("ashby_questions.json", Submitters::Ashby),
                  "_systemfield_name" => "Sara Ali", "_systemfield_email" => "sara@example.com", "_systemfield_resume" => "cv_pdf",
                  "#{P}5" => "https://www.linkedin.com/in/sara", "#{P}6" => "No", "#{P}7" => "1 month", "#{P}9" => "6")

    assert_equal [ "Sara Ali", "sara@example.com", "cv.pdf" ], filled.values_at("_systemfield_name", "_systemfield_email", "_systemfield_resume")
    assert_equal [ "https://www.linkedin.com/in/sara", "No", "1m", "6" ], filled.values_at("#{P}5", "#{P}6", "#{P}7", "#{P}9")
  end

  test "lever" do
    filled = fill("lever", questions_from("lever_form.html", Submitters::Lever),
                  "resume" => "cv_pdf", "name" => "Sara Ali", "email" => "sara@example.com", "urls[LinkedIn]" => "https://www.linkedin.com/in/sara",
                  "cards[5a7b9c][field0]" => "Yes", "cards[5a7b9c][field1]" => [ "Paid social", "Events" ])

    assert_equal [ "Sara Ali", "sara@example.com", "cv.pdf" ], filled.values_at("name", "email", "resume")
    assert_equal [ "https://www.linkedin.com/in/sara", "Yes" ], filled.values_at("urls[LinkedIn]", "cards[5a7b9c][field0]")
    assert_equal [ "Paid social", "Events" ], Rack::Utils.parse_query(@query)["cards[5a7b9c][field1]"]
    assert_equal "", filled["eeo[gender]"]
  end

  test "workable" do
    filled = fill("workable", questions_from("workable_questions.json", Submitters::Workable),
                  "firstname" => "Sara", "lastname" => "Ali", "email" => "sara@example.com", "resume" => "cv_pdf",
                  "QA_6170001" => "Yes", "QA_6170002" => "Jeddah", "QA_6170003" => %w[Arabic English])

    assert_equal [ "Sara", "Ali", "sara@example.com", "cv.pdf" ], filled.values_at("firstname", "lastname", "email", "resume")
    assert_equal [ "true", "2" ], filled.values_at("QA_6170001", "QA_6170002")
    assert_equal %w[1 2], Rack::Utils.parse_query(@query)["QA_6170003"]
  end

  private

  def chrome?
    Ferrum::Browser::Options::Chrome.options.detect_path.present?
  rescue StandardError
    false
  end

  def questions_from(fixture, submitter)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(FORMS.join(fixture).read)
    Net::HTTP.stubs(:start).returns(response)
    employer = JobApplications::Employer.new(ats: submitter.name.demodulize.downcase, identifier: "acme")
    submitter.questions(JobApplications::Posting.new(employer:, external_id: "job-1", apply_url: "https://jobs.lever.co/acme/job-1/apply"))
  ensure
    Net::HTTP.unstub(:start)
  end

  # Runs the submitter on the local form and returns the submitted fields.
  def fill(ats, questions, answers)
    employer = create_employer(ats:, identifier: "acme-#{ats}")
    app = create_application(@user, posting: create_posting(employer), status: "sending", questions:, answers:, claimed_at: Time.current, attempts: 1)
    add_cv_pdf(app)
    submitter = "JobApplications::Submitters::#{ats.classify}".constantize.new(app, cv_pdf: "%PDF-1.4 tailored")
    submitter.stubs(:form_url).returns("file://#{FORMS.join("#{ats}_form.html")}")
    submitter.stubs(:allowlist).returns([ %r{\Afile://} ])

    result = submitter.call

    assert result.sent?, "expected a confirmed send, got #{result.error_code.inspect}"
    assert_equal "image/jpeg", result.proof_type
    assert result.proof_bytes.start_with?("\xFF\xD8".b), "the proof is a JPEG"
    assert_not_nil app.reload.submit_clicked_at
    url = result.confirmation[:url]
    assert_includes url, "#{ats}_confirmation.html"
    @query = URI(url).query.to_s
    Rack::Utils.parse_query(@query).transform_values { |v| v.is_a?(Array) && v.size == 1 ? v.first : v }
  end
end
