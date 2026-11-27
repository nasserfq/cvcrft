require "application_system_test_case"
require_relative "../../support/seera_apply_helper"

class JobApplications::ApplyFlowTest < ApplicationSystemTestCase
  include Devise::Test::IntegrationHelpers
  include SeeraApplyHelper

  setup do
    @user = users(:one)
    ENV["SEERA_APPLY_TESTERS"] = @user.email
    finished_resume(@user)
    create_preference(@user)
    sign_in @user
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  test "set up, approve a prepared application, and it waits in Queued" do
    visit my_jobs_root_path(locale: "en")
    decline_analytics_banner
    find("[data-testid=apply-setup] a").click

    fill_in I18n.t("seera_apply.setup.nationality", locale: :en), with: "Saudi"
    select I18n.t("seera_apply.setup.visa_statuses.saudi_citizen", locale: :en), from: I18n.t("seera_apply.setup.visa_status", locale: :en)
    select I18n.t("seera_apply.setup.notice_periods.one_month", locale: :en), from: I18n.t("seera_apply.setup.notice_period", locale: :en)
    fill_in I18n.t("seera_apply.setup.phone", locale: :en), with: "+966 500000000"
    fill_in I18n.t("seera_apply.setup.linkedin_url", locale: :en), with: "https://www.linkedin.com/in/sara"
    check I18n.t("seera_apply.setup.consent", locale: :en)
    click_on I18n.t("seera_apply.setup.turn_on", locale: :en)

    assert_selector "[data-testid=apply-switch] [data-testid=state-on][aria-pressed=true]"
    assert JobApplications::Profile.find_by!(user: @user).sending?

    app = create_application(@user, status: "needs_approval", approval_required: true,
                                    posting: create_posting(create_employer(name: "Noon"), title: "Growth Lead"))
    visit my_jobs_root_path(locale: "en")
    assert_selector "[data-testid=tab-approval][aria-current=page]"

    within("##{ActionView::RecordIdentifier.dom_id(app)}") { click_on I18n.t("seera_apply.apply.approve", locale: :en) }

    assert_selector "[data-testid=tab-queued][aria-current=page]"
    assert_selector "##{ActionView::RecordIdentifier.dom_id(app)}[data-status=queued]", text: "Growth Lead"
    assert_equal "queued", app.reload.status
  end

  private

  def decline_analytics_banner
    decline = I18n.t("consent.decline", locale: :en)
    click_on(decline) if has_button?(decline, wait: 1)
  end
end
