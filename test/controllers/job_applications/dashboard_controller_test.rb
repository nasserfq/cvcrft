require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::DashboardControllerTest < ActionDispatch::IntegrationTest
  include SeeraApplyHelper

  setup do
    @user = users(:one)
    sign_in @user
    ENV["SEERA_APPLY_TESTERS"] = @user.email
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  test "is hidden when Seera Apply is off" do
    ENV.delete("SEERA_APPLY_TESTERS")

    # A 404 doesn't write the session, so sign in again before each request.
    get my_jobs_root_url
    assert_response :not_found
    sign_in @user
    patch my_jobs_preferences_url, params: { preference: { titles: "Nurse" } }
    assert_response :not_found
  end

  test "signed out goes to sign in" do
    sign_out @user

    get my_jobs_root_url
    assert_response :redirect
  end

  test "without a finished CV it links to the builder and shows no form" do
    get my_jobs_root_url(locale: "en")

    assert_response :success
    assert_select "[data-testid=no-cv] a[href='#{new_resume_path}']", I18n.t("seera_apply.build_cv", locale: :en)
    assert_select "form[action='#{my_jobs_preferences_path}']", 0
  end

  test "with a CV and no preferences it opens with the form" do
    finished_resume(@user)

    get my_jobs_root_url(locale: "en")

    assert_response :success
    assert_select "[data-testid=preferences] form[action='#{my_jobs_preferences_path}']" do
      assert_select "input[name='preference[titles]']"
      JobApplications::CITIES.each { |city| assert_select "input[type=checkbox][name='preference[cities][]'][value=#{city}]" }
    end
    assert_select "[data-testid=count]", 0
  end

  test "with matches it shows the count and one linked row per shown match" do
    finished_resume(@user)
    create_preference(@user)
    good = create_match(@user, score: 9)
    also = create_match(@user, score: 7, posting: create_posting(create_employer(name: "Noon"), city: "remote", location: "Remote"))
    create_match(@user, score: 4)
    create_match(@user, score: 8, posting: create_posting(create_employer, closed_at: 1.hour.ago))
    create_match(users(:two), score: 10)

    get my_jobs_root_url(locale: "en")

    assert_response :success
    assert_select "[data-testid=count] h1", /\A\s*2\s+#{I18n.t('seera_apply.count', locale: :en)}\s*\z/
    assert_select "[data-testid=matches] li", 2
    assert_select "li##{ActionView::RecordIdentifier.dom_id(good)} a[href='#{good.posting.url}'][target=_blank][rel='noopener noreferrer']" do
      assert_select "[data-testid=score]", "9/10"
    end
    assert_select "li##{ActionView::RecordIdentifier.dom_id(also)} a[href='#{also.posting.url}']", /Noon.*Remote/m
    assert_select "details summary", I18n.t("seera_apply.edit", locale: :en)
  end

  test "zero matches shows 0 and nothing else" do
    finished_resume(@user)
    create_preference(@user)

    get my_jobs_root_url(locale: "en")

    assert_select "[data-testid=count] h1", /\A\s*0\s/
    assert_select "[data-testid=matches]", 0
  end

  test "renders in Arabic, right to left" do
    finished_resume(@user)
    create_preference(@user)
    create_match(@user)

    get my_jobs_root_url(locale: "ar")

    assert_response :success
    assert_select "div.sr-page[dir=rtl]"
    assert_select "[data-testid=count]", /#{I18n.t('seera_apply.count', locale: :ar)}/
    assert_select "[data-testid=matches]", /#{I18n.t('seera_apply.cities.riyadh', locale: :ar)}/
  end

  test "with no apply profile an Apply for me card sits above the count" do
    finished_resume(@user)
    create_preference(@user)

    get my_jobs_root_url(locale: "en")

    assert_select "[data-testid=apply-setup] a[href='#{my_jobs_setup_path}']"
    assert_select "[data-testid=apply-switch]", 0
    assert_select "[data-testid=apply-tabs]", 0
    assert_select "[data-testid=apply-setup] ~ [data-testid=count]"
  end

  test "the switch shows the state and the five tabs show counts, opening on the first that needs the user" do
    finished_resume(@user)
    create_preference(@user)
    create_profile(@user, state: "paused")
    create_application(@user, status: "queued", hold: "daily_cap")
    create_application(@user, status: "preparing")
    approval = create_application(@user, status: "needs_approval", approval_required: true,
                                         questions: [ { "id" => "q1", "label" => "Why us?", "type" => "textarea" } ],
                                         answers: { "q1" => "Mission." })
    add_cv_pdf(approval)
    create_application(@user, status: "sent", sent_at: Time.zone.parse("2026-11-20 10:00"))
    create_application(@user, status: "skipped")
    create_application(users(:two), status: "needs_approval")

    get my_jobs_root_url(locale: "en")

    assert_select "[data-testid=apply-switch] button[data-testid=state-paused][aria-pressed=true]"
    assert_select "[data-testid=apply-switch] button[data-testid=state-on][aria-pressed=false]"
    { "queued" => 2, "approval" => 1, "answer" => 0, "sent" => 1, "failed" => 0 }.each do |tab, count|
      assert_select "[data-testid=tab-#{tab}][href=?]", my_jobs_root_path(tab:), /#{I18n.t("seera_apply.apply.tabs.#{tab}", locale: :en)}\s*#{count}/
    end
    assert_select "[data-testid=tab-approval][aria-current=page]"
    assert_select "[data-testid=applications] li", 1
    assert_select "li##{ActionView::RecordIdentifier.dom_id(approval)}" do
      assert_select "form[action='#{approve_my_jobs_application_path(approval)}']"
      assert_select "form[action='#{skip_my_jobs_application_path(approval)}']"
      assert_select "a[data-testid=cv][href='#{cv_my_jobs_application_path(approval)}']"
      assert_select "details dl", /Why us\?\s*Mission\./
    end
  end

  test "queued shows hold labels, and no credits links to credits only with billing on" do
    finished_resume(@user)
    create_preference(@user)
    create_profile(@user)
    create_application(@user, status: "queued", hold: "no_credits")

    get my_jobs_root_url(locale: "en", tab: "queued")
    assert_select "[data-testid=status]", I18n.t("seera_apply.hold.no_credits", locale: :en)
    assert_select "a[href='#{credits_path}'][data-testid=status]", 0

    ENV["BILLING_TESTERS"] = @user.email
    get my_jobs_root_url(locale: "en", tab: "queued")
    assert_select "a[href='#{credits_path}'][data-testid=status]", I18n.t("seera_apply.hold.no_credits", locale: :en)
  ensure
    ENV.delete("BILLING_TESTERS")
  end

  test "needs answer shows the missing questions as fields" do
    finished_resume(@user)
    create_preference(@user)
    create_profile(@user)
    app = create_application(@user, status: "needs_answer", missing: %w[q1 q2 q3], questions: [
      { "id" => "q1", "label" => "Salary?", "type" => "number", "required" => true },
      { "id" => "q2", "label" => "Relocate?", "type" => "select", "options" => [ { "label" => "Yes", "value" => "1" }, { "label" => "No", "value" => "0" } ] },
      { "id" => "q3", "label" => "Tools", "type" => "checkbox", "options" => %w[Figma Jira] },
      { "id" => "q4", "label" => "Answered", "type" => "text" }
    ])

    get my_jobs_root_url(locale: "en")

    assert_select "[data-testid=tab-answer][aria-current=page]"
    assert_select "form[action='#{answer_my_jobs_application_path(app)}']" do
      assert_select "input[type=number][name='answers[q1]'][required]"
      assert_select "select[name='answers[q2]'] option[value='1']", "Yes"
      assert_select "input[type=checkbox][name='answers[q3][]']", 2
      assert_select "[name='answers[q4]']", 0
    end
  end

  test "sent shows the date and proof; failed links to the job page and the CV" do
    finished_resume(@user)
    create_preference(@user)
    create_profile(@user)
    sent = create_application(@user, status: "sent", sent_at: Time.zone.parse("2026-11-20 10:00"))
    JobApplications::Document.store!(sent, kind: "proof", data: "jpeg", content_type: "image/jpeg", filename: "proof.jpg")
    failed = create_application(@user, status: "failed_fallback", error_code: "captcha")
    add_cv_pdf(failed)

    get my_jobs_root_url(locale: "en", tab: "sent")
    assert_select "[data-testid=sent-at]", "2026-11-20"
    assert_select "a[data-testid=proof][href='#{proof_my_jobs_application_path(sent)}']"

    get my_jobs_root_url(locale: "en", tab: "failed")
    assert_select "li##{ActionView::RecordIdentifier.dom_id(failed)}" do
      assert_select "[data-testid=status]", I18n.t("seera_apply.errors.captcha", locale: :en)
      assert_select "a[data-testid=open-job][href='#{failed.posting.apply_url}'][target=_blank][rel='noopener noreferrer']",
                    /#{I18n.t('seera_apply.apply.open_job', locale: :en)}/
      assert_select "a[data-testid=cv][href='#{cv_my_jobs_application_path(failed)}']"
    end
  end

  test "the tracker renders in Arabic" do
    finished_resume(@user)
    create_preference(@user)
    create_profile(@user)
    create_application(@user, status: "needs_approval")

    get my_jobs_root_url(locale: "ar")

    assert_response :success
    assert_select "div.sr-page[dir=rtl] [data-testid=apply-switch]", /#{I18n.t('seera_apply.apply.title', locale: :ar)}/
    assert_select "[data-testid=tab-approval]", /#{I18n.t('seera_apply.apply.tabs.approval', locale: :ar)}/
    assert_select "[data-testid=applications] button", /#{I18n.t('seera_apply.apply.approve', locale: :ar)}/
  end

  test "the header links to the page only for testers" do
    get resumes_url
    assert_select "header a[href='#{my_jobs_root_path}']", I18n.t("nav.jobs", locale: :ar)

    ENV.delete("SEERA_APPLY_TESTERS")
    get resumes_url
    assert_select "a[href='#{my_jobs_root_path}']", 0
  end
end
