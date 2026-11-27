require "test_helper"
require_relative "../../../support/seera_apply_helper"
require_relative "fake_page"

class JobApplications::Submitters::LeverTest < ActiveSupport::TestCase
  include SeeraApplyHelper
  include SubmitterFakes

  Lever = JobApplications::Submitters::Lever
  SUBMIT = Lever.new(nil, cv_pdf: nil).send(:submit_selector)

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(file_fixture("ats_forms/lever_form.html").read)
    Net::HTTP.stubs(:start).with("jobs.lever.co", 443, has_entries(use_ssl: true, open_timeout: 5, read_timeout: 20)).returns(response)
    attrs = { external_id: "lv-1", apply_url: "https://jobs.lever.co/acme/lv-1/apply" }
    @questions = Lever.questions(JobApplications::Posting.new(employer: JobApplications::Employer.new(ats: "lever", identifier: "acme"), **attrs))
    answers = { "resume" => "cv_pdf", "name" => "Sara Ali", "email" => "sara@example.com", "cards[5a7b9c][field0]" => "Yes",
                "cards[5a7b9c][field1]" => [ "SEO" ] }
    @app = sending_application(ats: "lever", questions: @questions, answers:, posting_attrs: attrs)
    @required = %w[resume name email cards[5a7b9c][field0]].map { |n| { "id" => "", "name" => n } }
  end

  teardown { ENV.delete("SEERA_APPLY_DRY_RUN") }

  def page(**options)
    FakePage.new(required: @required, after_submit: { url: "https://jobs.lever.co/acme/lv-1/thanks", text: "Application submitted!" }, **options)
  end

  test "questions are read from the apply page HTML" do
    by_id = @questions.index_by { |q| q["id"] }

    assert_equal %w[resume name email phone org urls[LinkedIn] cards[5a7b9c][field0] cards[5a7b9c][field1] eeo[gender] comments],
                 @questions.map { |q| q["id"] }
    assert_equal [ "Resume/CV", "file", true ], by_id["resume"].values_at("label", "type", "required")
    assert_equal [ "Full name", "text", true ], by_id["name"].values_at("label", "type", "required")
    assert_equal [ "email", false ], [ by_id["email"]["type"], by_id["phone"]["required"] ]
    assert_equal [ "Are you authorized to work in Saudi Arabia?", "radio", %w[Yes No], true ],
                 by_id["cards[5a7b9c][field0]"].values_at("label", "type", "options", "required")
    assert_equal [ "checkbox", [ "Paid social", "SEO", "Events" ] ], by_id["cards[5a7b9c][field1]"].values_at("type", "options")
    assert_equal [ "select", [ "Female", "Male", "Decline to self-identify" ], "eeo" ], by_id["eeo[gender]"].values_at("type", "options", "section")
    assert_equal "textarea", by_id["comments"]["type"]
  end

  test "fills by name and confirms on the thanks page" do
    fake = page
    result = submitter_for(@app, fake).call

    assert result.sent?
    assert_equal "https://jobs.lever.co/acme/lv-1/apply", fake.logged(:go_to).sole.last
    assert_includes fake.log, [ :set, '[name="name"]', "Sara Ali" ]
    assert_includes fake.log, [ :check, "cards[5a7b9c][field0]", [ "Yes" ] ]
    assert_includes fake.log, [ :check, "cards[5a7b9c][field1]", [ "SEO" ] ]
    assert_equal "%PDF-1.4 tailored", fake.logged(:file).sole.last
    assert_equal [ [ :click, SUBMIT ] ], fake.logged(:click)
  end

  test "unknown required field, captcha, timeout, Retryable and dry run" do
    unknown = page(required: @required + [ { "id" => "", "name" => "cards[5a7b9c][field9]" } ])
    assert_equal "unknown_field", submitter_for(@app, unknown).call.error_code
    assert_empty unknown.logged(:click)

    assert_equal "captcha", submitter_for(@app, page(captcha: true)).call.error_code
    assert_raises(JobApplications::Submitters::Retryable) { submitter_for(@app, page(on_go_to: -> { raise Ferrum::TimeoutError })).call }

    ENV["SEERA_APPLY_DRY_RUN"] = "true"
    dry = page
    assert_equal "dry_run", submitter_for(@app, dry).call.error_code
    assert_empty dry.logged(:click)
    ENV.delete("SEERA_APPLY_DRY_RUN")

    assert_equal "timeout", submitter_for(@app, page(after_submit: { text: "Please complete the captcha" })).call.error_code
  end
end
