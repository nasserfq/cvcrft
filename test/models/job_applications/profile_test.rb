require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::ProfileTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  setup { @user = users(:one) }

  def build(attrs = {})
    JobApplications::Profile.new({ user: @user, nationality: "Saudi", visa_status: "saudi_citizen", notice_period: "immediate",
                                   phone: "+966 50 000 0000", linkedin_url: "https://linkedin.com/in/sara" }.merge(attrs))
  end

  test "a complete setup is valid and starts off" do
    profile = build

    assert profile.valid?
    assert_equal "off", profile.state
    assert_not profile.sending?
  end

  test "validates the six answers" do
    assert build(expected_salary_sar: 15_000).valid?
    assert build(linkedin_url: "https://sa.linkedin.com/in/sara").valid?
    {
      nationality: "", visa_status: "tourist", notice_period: "a year", phone: "call me", expected_salary_sar: -5,
      linkedin_url: "http://linkedin.com/in/sara"
    }.each { |attr, value| assert_not build(attr => value).valid?, attr }
    assert_not build(linkedin_url: "https://evil-linkedin.com/in/x").valid?
    assert_not build(phone: "+12345").valid?
    assert_not build(state: "maybe").valid?
  end

  test "give_consent! stores the version and time and turns sending on" do
    profile = build
    profile.save!

    freeze_time do
      profile.give_consent!
      assert_equal [ JobApplications::CONSENT_VERSION, Time.current, "on" ], [ profile.consent_version, profile.consented_at, profile.state ]
    end
    assert profile.consented?
    assert profile.sending?
  end

  test "an older consent version does not count" do
    profile = create_profile(@user, consent_version: "2025-01-01")

    assert_not profile.consented?
    assert_not profile.sending?
  end

  test "paused keeps consent but stops sending" do
    profile = create_profile(@user)
    profile.pause!

    assert profile.consented?
    assert_not profile.sending?
  end

  test "turn_off! clears consent" do
    profile = create_profile(@user)
    profile.turn_off!

    assert_equal [ "off", nil, nil ], [ profile.reload.state, profile.consent_version, profile.consented_at ]
    assert_not profile.consented?
  end

  test "remember_answers! keys by normalized label" do
    profile = create_profile(@user)
    profile.remember_answers!("  Years of SQL? " => "4", "Empty" => "")

    assert_equal({ "years of sql" => "4" }, profile.reload.saved_answers)
    assert_equal "4", profile.saved_answer("YEARS OF SQL")
  end
end
