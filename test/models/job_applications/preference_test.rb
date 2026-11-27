require "test_helper"

class JobApplications::PreferenceTest < ActiveSupport::TestCase
  def preference(attrs = {}) = JobApplications::Preference.new({ user: users(:one) }.merge(attrs))

  test "empty preferences are valid but not ready" do
    p = preference
    assert_valid p
    assert_equal [ [], [] ], [ p.titles, p.cities ]
    assert_not p.ready?
  end

  test "ready with at least one title and one city" do
    assert preference(titles: [ "Nurse" ], cities: [ "jeddah" ]).ready?
    assert_not preference(titles: [ "Nurse" ]).ready?
    assert_not preference(cities: [ "jeddah" ]).ready?
  end

  test "cities are the four the page offers" do
    assert_valid preference(cities: JobApplications::CITIES)
    assert_has_errors preference(cities: [ "dubai" ]), :cities
    assert_has_errors preference(cities: [ "riyadh", "SA" ]), :cities
  end

  test "titles are capped" do
    assert_valid preference(titles: Array.new(10) { |i| "Title #{i}" })
    assert_has_errors preference(titles: Array.new(11) { |i| "Title #{i}" }), :titles
    assert_has_errors preference(titles: [ "x" * 81 ]), :titles
  end
end
