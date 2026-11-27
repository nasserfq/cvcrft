require "test_helper"
require_relative "../../../support/seera_apply_helper"
require_relative "fake_page"

class JobApplications::Submitters::AshbyTest < ActiveSupport::TestCase
  include SeeraApplyHelper
  include SubmitterFakes

  Ashby = JobApplications::Submitters::Ashby
  P = "8c1d2e3f-aaaa-4bbb-8ccc-00000000000".freeze
  SUBMIT = Ashby.new(nil, cv_pdf: nil).send(:submit_selector)

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(file_fixture("ats_forms/ashby_questions.json").read)
    Net::HTTP.stubs(:start).with("jobs.ashbyhq.com", 443, has_entries(use_ssl: true, open_timeout: 5, read_timeout: 20)).returns(response)
    posting = JobApplications::Posting.new(employer: JobApplications::Employer.new(ats: "ashby", identifier: "acme"), external_id: "3f2a1c9e")
    @questions = Ashby.questions(posting)
    answers = { "_systemfield_name" => "Sara Ali", "_systemfield_email" => "sara@example.com", "_systemfield_resume" => "cv_pdf",
                "#{P}5" => "https://www.linkedin.com/in/sara", "#{P}6" => "No", "#{P}7" => "1 month" }
    @app = sending_application(ats: "ashby", questions: @questions, answers:, posting_attrs: { external_id: "3f2a1c9e" })
    @required = %w[_systemfield_name _systemfield_email _systemfield_resume].map { |n| { "id" => n, "name" => n } } +
                [ { "id" => "", "name" => "#{P}6" }, { "id" => "", "name" => "#{P}7" } ]
  end

  teardown { ENV.delete("SEERA_APPLY_DRY_RUN") }

  def page(**options)
    FakePage.new(required: @required, input_types: { %([name="#{P}7"]) => "radio" },
                 after_submit: { shows: [ Ashby::SUCCESS_SELECTOR ] }, **options)
  end

  test "questions come from applicationForm, skipping field types it can't fill" do
    by_id = @questions.index_by { |q| q["id"] }

    assert_equal %w[_systemfield_name _systemfield_email _systemfield_phone _systemfield_resume] + (5..9).map { |n| "#{P}#{n}" } + [ "#{P[0..-2]}11" ],
                 @questions.map { |q| q["id"] }
    assert_equal [ "text", true ], by_id["_systemfield_name"].values_at("type", "required")
    assert_equal [ "tel", false ], by_id["_systemfield_phone"].values_at("type", "required")
    assert_equal [ "radio", %w[Yes No] ], by_id["#{P}6"].values_at("type", "options")
    assert_equal [ "select", [ "Immediately", "1 month", "3 months" ] ], by_id["#{P}7"].values_at("type", "options")
    assert_equal [ "textarea", "number" ], [ by_id["#{P}8"]["type"], by_id["#{P}9"]["type"] ]
    assert_equal false, by_id["#{P}9"]["required"], "isNullable decides when isRequired is absent"
    assert_equal "url", by_id["#{P}5"]["type"]
    assert_equal "eeo", by_id["#{P[0..-2]}11"]["section"]
  end

  test "fills by name, picks radio options, attaches the CV and confirms" do
    fake = page
    result = submitter_for(@app, fake).call

    assert result.sent?
    assert_equal "https://jobs.ashbyhq.com/acme/3f2a1c9e/application", fake.logged(:go_to).sole.last
    assert_includes fake.log, [ :set, '[name="_systemfield_name"]', "Sara Ali" ]
    assert_includes fake.log, [ :set, %([name="#{P}5"]), "https://www.linkedin.com/in/sara" ]
    assert_includes fake.log, [ :check, "#{P}6", [ "No" ] ]
    assert_includes fake.log, [ :check, "#{P}7", [ "1 month" ] ], "a select rendered as radios is ticked"
    assert_equal 'input[type="file"][name="_systemfield_resume"], input[type="file"][id="_systemfield_resume"]', fake.logged(:file).sole[1]
    assert_equal [ [ :click, SUBMIT ] ], fake.logged(:click)
  end

  test "an unanswered required question stops before Submit" do
    @app.update!(answers: @app.answers.except("#{P}6"))
    fake = page

    assert_equal "unknown_field", submitter_for(@app, fake).call.error_code
    assert_empty fake.logged(:click)
  end

  test "captcha, timeout, Retryable and dry run" do
    assert_equal "captcha", submitter_for(@app, page(captcha: true)).call.error_code
    assert_equal "timeout", submitter_for(@app, page(missing: [ Ashby::SUCCESS_SELECTOR ], after_submit: { text: "Missing entry for required field" })).call.error_code

    @app.update_columns(submit_clicked_at: nil)
    assert_raises(JobApplications::Submitters::Retryable) { submitter_for(@app, page(on_go_to: -> { raise Ferrum::DeadBrowserError })).call }

    ENV["SEERA_APPLY_DRY_RUN"] = "true"
    fake = page
    assert_equal "dry_run", submitter_for(@app, fake).call.error_code
    assert_empty fake.logged(:click)
    assert_equal 1, fake.logged(:screenshot).size
  end
end
