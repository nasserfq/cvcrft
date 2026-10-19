require "test_helper"

class JobApplications::GulfLocationTest < ActiveSupport::TestCase
  G = JobApplications::GulfLocation

  test "English cities and countries" do
    assert_equal "SA", G.country_for("Riyadh, Saudi Arabia")
    assert_equal "SA", G.country_for("Al Khobar")
    assert_equal "SA", G.country_for("NEOM")
    assert_equal "AE", G.country_for("Abu Dhabi")
    assert_equal "AE", G.country_for("Dubai - United Arab Emirates")
    assert_equal "QA", G.country_for("Doha")
    assert_equal "KW", G.country_for("Kuwait City")
    assert_equal "BH", G.country_for("Manama, Bahrain")
    assert_equal "OM", G.country_for("Muscat")
  end

  test "Arabic names, with or without hamza and taa marbuta" do
    assert_equal "SA", G.country_for("الرياض")
    assert_equal "SA", G.country_for("المملكة العربية السعوديه")
    assert_equal "SA", G.country_for("ابها")
    assert_equal "AE", G.country_for("أبوظبي")
    assert_equal "AE", G.country_for("الامارات")
    assert_equal "QA", G.country_for("الدوحة")
  end

  test "ISO codes from the feeds" do
    assert_equal "SA", G.country_for("SA")
    assert_equal "SA", G.country_for("SAU")
    assert_equal "AE", G.country_for("ARE")
    assert_equal "SA", G.country_for("Riyadh, SA")
    assert_equal "SA", G.country_for("sa")
  end

  test "word boundaries keep look-alikes out" do
    assert_nil G.country_for("Omaha, NE")
    assert_nil G.country_for("Bucharest, Romania")
    assert_nil G.country_for("London")
    assert_nil G.country_for("Amman, Jordan")
    assert_nil G.country_for("Sao Paulo")
    assert_nil G.country_for("", nil)
  end

  test "first string that names a Gulf country wins" do
    assert_equal "AE", G.country_for(nil, "Dubai", "SA")
  end

  test "the employer's country is only a fallback for empty or remote locations" do
    assert_equal "SA", G.for_posting(location: "Remote", fallback: "SA")
    assert_equal "SA", G.for_posting(location: "", fallback: "SA")
    assert_equal "SA", G.for_posting(location: nil, fallback: "SA")
    assert_nil G.for_posting(location: "London, UK", fallback: "SA")
    assert_nil G.for_posting(location: "Remote", country: "US", fallback: "SA")
    assert_equal "QA", G.for_posting(location: "Remote", country: "QA", fallback: "SA")
  end

  test "mislabelled encodings do not raise" do
    assert_equal "SA", G.country_for("الرياض".b)
  end
end
