require "test_helper"
require_relative "../../../support/seera_apply_helper"
require_relative "fake_page"

class JobApplications::Submitters::WorkableTest < ActiveSupport::TestCase
  include SeeraApplyHelper
  include SubmitterFakes

  Workable = JobApplications::Submitters::Workable
  SUBMIT = Workable.new(nil, cv_pdf: nil).send(:submit_selector)

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.stubs(:body).returns(file_fixture("ats_forms/workable_questions.json").read)
    Net::HTTP.stubs(:start).with("apply.workable.com", 443, has_entries(use_ssl: true, open_timeout: 5, read_timeout: 20)).returns(response)
    @questions = Workable.questions(JobApplications::Posting.new(employer: JobApplications::Employer.new(ats: "workable", identifier: "acme"), external_id: "AB12CD"))
    answers = { "firstname" => "Sara", "lastname" => "Ali", "email" => "sara@example.com", "resume" => "cv_pdf",
                "QA_6170001" => "Yes", "QA_6170002" => "Riyadh" }
    @app = sending_application(ats: "workable", questions: @questions, answers:, posting_attrs: { external_id: "AB12CD" })
    @required = %w[firstname lastname email resume QA_6170001].map { |n| { "id" => n, "name" => n } }
  end

  teardown { ENV.delete("SEERA_APPLY_DRY_RUN") }

  def page(**options)
    FakePage.new(required: @required, tags: { '[name="QA_6170002"], [id="QA_6170002"]' => "select" },
                 after_submit: { text: "Thank you for applying!" }, **options)
  end

  test "questions come from the form JSON, skipping field types it can't fill" do
    by_id = @questions.index_by { |q| q["id"] }

    assert_equal %w[firstname lastname email phone resume QA_6170001 QA_6170002 QA_6170003 QA_6170004], @questions.map { |q| q["id"] }
    assert_equal [ "tel", false ], by_id["phone"].values_at("type", "required")
    assert_equal [ "file", true ], by_id["resume"].values_at("type", "required")
    assert_equal [ "radio", %w[Yes No], true ], by_id["QA_6170001"].values_at("type", "options", "required")
    assert_equal [ "select", %w[Riyadh Jeddah] ], by_id["QA_6170002"].values_at("type", "options")
    assert_equal [ "checkbox", %w[Arabic English] ], by_id["QA_6170003"].values_at("type", "options")
    assert_equal "textarea", by_id["QA_6170004"]["type"]
  end

  test "fills by name or id, picks the select option by text and confirms" do
    fake = page
    result = submitter_for(@app, fake).call

    assert result.sent?
    assert_equal "https://apply.workable.com/acme/j/AB12CD/apply/", fake.logged(:go_to).sole.last
    assert_includes fake.log, [ :set, '[name="firstname"], [id="firstname"]', "Sara" ]
    assert_includes fake.log, [ :check, "QA_6170001", [ "Yes" ] ]
    assert_includes fake.log, [ :select, '[name="QA_6170002"], [id="QA_6170002"]', "Riyadh", :text ]
    assert_equal 1, fake.logged(:file).size
    assert_equal [ [ :click, SUBMIT ] ], fake.logged(:click)
  end

  test "unknown required field, captcha, timeout, Retryable and dry run" do
    unknown = page(required: @required + [ { "id" => "QA_6170099", "name" => "QA_6170099" } ])
    assert_equal "unknown_field", submitter_for(@app, unknown).call.error_code
    assert_empty unknown.logged(:click)

    assert_equal "captcha", submitter_for(@app, page(captcha: true)).call.error_code
    assert_raises(JobApplications::Submitters::Retryable) { submitter_for(@app, page(on_go_to: -> { raise Ferrum::TimeoutError })).call }

    ENV["SEERA_APPLY_DRY_RUN"] = "true"
    dry = page
    assert_equal "dry_run", submitter_for(@app, dry).call.error_code
    assert_empty dry.logged(:click)
    ENV.delete("SEERA_APPLY_DRY_RUN")

    assert_equal "timeout", submitter_for(@app, page(after_submit: { text: "Something went wrong" })).call.error_code
  end
end
