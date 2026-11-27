require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::ProfilesControllerTest < ActionDispatch::IntegrationTest
  include SeeraApplyHelper

  VALID = {
    nationality: "Saudi", visa_status: "saudi_citizen", notice_period: "one_month", expected_salary_sar: "15,000",
    phone: "+966 500000000", linkedin_url: "https://www.linkedin.com/in/sara"
  }.freeze

  setup do
    @user = users(:one)
    sign_in @user
    ENV["SEERA_APPLY_TESTERS"] = @user.email
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  def save(profile = VALID, consent: "1")
    patch my_jobs_setup_url(locale: "en"), params: { profile:, consent: }
  end

  test "is a 404 when Seera Apply is off" do
    ENV.delete("SEERA_APPLY_TESTERS")

    get my_jobs_setup_url
    assert_response :not_found
    sign_in @user
    save
    assert_response :not_found
    sign_in @user
    patch my_jobs_sending_url, params: { state: "on" }
    assert_response :not_found
    assert_nil JobApplications::Profile.find_by(user: @user)
  end

  test "the setup form has the six fields and the consent box, in both languages" do
    %w[en ar].each do |locale|
      get my_jobs_setup_url(locale:)

      assert_response :success
      assert_select "form[action='#{my_jobs_setup_path}']" do
        %w[nationality visa_status notice_period expected_salary_sar phone linkedin_url].each do |field|
          assert_select "[name='profile[#{field}]']"
        end
        assert_select "input[type=checkbox][name=consent][required]"
        assert_select "[data-testid=consent]", /#{Regexp.escape(I18n.t('seera_apply.setup.consent', locale:))}/
        assert_select "[data-testid=consent] a[href^='#{privacy_path}']"
      end
    end
    assert_select "div.sr-page[dir=rtl]"
  end

  test "the phone starts from the newest CV when it fits" do
    finished_resume(@user, phone_number: "+966 512345678")

    get my_jobs_setup_url(locale: "en")

    assert_select "input[name='profile[phone]'][value='+966 512345678']"
  end

  test "consent is required to turn it on" do
    save(consent: "0")

    assert_response :unprocessable_content
    assert_nil JobApplications::Profile.find_by(user: @user)
    assert_select "[data-testid=setup-errors]", /#{I18n.t('seera_apply.setup.consent_required', locale: :en)}/
  end

  test "with consent it saves the answers and turns sending on" do
    save

    assert_redirected_to my_jobs_root_path
    profile = JobApplications::Profile.find_by!(user: @user)
    assert profile.sending?
    assert_equal JobApplications::CONSENT_VERSION, profile.consent_version
    assert_equal 15_000, profile.expected_salary_sar
    assert_equal "+966 500000000", profile.phone
  end

  test "salary is optional" do
    save(VALID.merge(expected_salary_sar: ""))

    assert_nil JobApplications::Profile.find_by!(user: @user).expected_salary_sar
  end

  test "invalid answers render the form again with the fields named" do
    save(VALID.merge(phone: "call me", linkedin_url: "http://linkedin.com/in/sara", visa_status: "tourist"))

    assert_response :unprocessable_content
    assert_nil JobApplications::Profile.find_by(user: @user)
    assert_select "[data-testid=setup-errors]" do |alert|
      text = alert.text
      %w[phone linkedin_url visa_status].each { |field| assert_includes text, I18n.t("seera_apply.setup.#{field}", locale: :en) }
    end
    assert_select "input[name='profile[phone]'][aria-invalid=true]"
    assert_select "input[name='profile[nationality]'][aria-invalid=true]", 0
  end

  test "editing keeps a paused switch paused" do
    create_profile(@user, state: "paused")

    save(VALID.merge(notice_period: "immediate"))

    profile = JobApplications::Profile.find_by!(user: @user)
    assert_equal "paused", profile.state
    assert_equal "immediate", profile.notice_period
  end

  test "sending switches between on, paused and off" do
    profile = create_profile(@user)

    patch my_jobs_sending_url, params: { state: "paused" }
    assert_redirected_to my_jobs_root_path
    assert profile.reload.paused?

    patch my_jobs_sending_url, params: { state: "on" }
    assert profile.reload.sending?
  end

  test "off withdraws consent, and on then goes back through setup" do
    profile = create_profile(@user)

    patch my_jobs_sending_url, params: { state: "off" }
    profile.reload
    assert_equal "off", profile.state
    assert_nil profile.consent_version
    assert_nil profile.consented_at

    patch my_jobs_sending_url, params: { state: "on" }
    assert_redirected_to my_jobs_setup_path
    assert_equal "off", profile.reload.state

    save
    assert profile.reload.sending?
  end

  test "sending without a profile goes to setup, and an unknown state is refused" do
    patch my_jobs_sending_url, params: { state: "on" }
    assert_redirected_to my_jobs_setup_path

    create_profile(@user)
    patch my_jobs_sending_url, params: { state: "auto" }
    assert_response :bad_request
  end
end
