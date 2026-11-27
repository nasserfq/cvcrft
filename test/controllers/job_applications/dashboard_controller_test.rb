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

  test "the header links to the page only for testers" do
    get resumes_url
    assert_select "header a[href='#{my_jobs_root_path}']", I18n.t("nav.jobs", locale: :ar)

    ENV.delete("SEERA_APPLY_TESTERS")
    get resumes_url
    assert_select "a[href='#{my_jobs_root_path}']", 0
  end
end
