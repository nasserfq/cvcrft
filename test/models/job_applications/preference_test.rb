require "test_helper"

class JobApplications::PreferenceTest < ActiveSupport::TestCase
  def preference(attrs = {}) = JobApplications::Preference.new({ user: users(:one) }.merge(attrs))

  test "defaults are valid" do
    p = preference
    assert_valid p
    assert_equal [ 7, 10, "review", [ "SA" ] ], [ p.min_score, p.daily_cap, p.mode, p.countries ]
  end

  test "min_score, daily_cap and mode stay in range" do
    assert_has_errors preference(min_score: 0), :min_score
    assert_has_errors preference(min_score: 11), :min_score
    assert_has_errors preference(daily_cap: 0), :daily_cap
    assert_has_errors preference(daily_cap: JobApplications::DAILY_CAP_MAX + 1), :daily_cap
    assert_has_errors preference(mode: "yolo"), :mode
    assert_valid preference(min_score: 10, daily_cap: JobApplications::DAILY_CAP_MAX, mode: "auto")
  end

  test "countries are Gulf codes and at least one" do
    assert_has_errors preference(countries: [ "US" ]), :countries
    assert_has_errors preference(countries: []), :countries
    assert_valid preference(countries: %w[SA AE QA KW BH OM])
  end

  test "linkedin_url must be an https linkedin.com link" do
    assert_valid preference(linkedin_url: "https://www.linkedin.com/in/sara")
    assert_valid preference(linkedin_url: "https://linkedin.com/in/sara")
    assert_has_errors preference(linkedin_url: "http://www.linkedin.com/in/sara"), :linkedin_url
    assert_has_errors preference(linkedin_url: "https://evil-linkedin.com/in/sara"), :linkedin_url
    assert_has_errors preference(linkedin_url: "javascript:alert(1)"), :linkedin_url
  end

  test "titles are capped" do
    assert_has_errors preference(titles: Array.new(11) { |i| "Title #{i}" }), :titles
    assert_has_errors preference(titles: [ "x" * 81 ]), :titles
  end

  test "consent_accepted? only with the current version" do
    assert_not preference.consent_accepted?
    assert_not preference(consent_accepted_at: Time.current, consent_version: "2020-01-01").consent_accepted?
    assert_not preference(consent_version: JobApplications::CONSENT_VERSION).consent_accepted?
    assert preference(consent_accepted_at: Time.current, consent_version: JobApplications::CONSENT_VERSION).consent_accepted?
  end
end
