require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should have proper HTML structure" do
    get root_url
    assert_select "html"
    assert_select "body"
  end

  test "billing testers see pricing on the landing page" do
    sign_in users(:one)
    ENV["BILLING_TESTERS"] = users(:one).email

    get root_url
    assert_select "[data-testid=landing-pricing]"
    assert_select "[data-testid=landing-pricing] article", Billing::PACKS.size + 1
  ensure
    ENV.delete("BILLING_TESTERS")
  end

  test "pricing stays hidden from everyone else" do
    get root_url
    assert_select "[data-testid=landing-pricing]", 0
    sign_in users(:one)
    get root_url
    assert_select "[data-testid=landing-pricing]", 0
  end

  test "testers see the AI Coach link in the header and the mobile menu" do
    sign_in users(:one)
    ENV["COACH_TESTERS"] = users(:one).email

    get root_url
    assert_select "a[href='/coach']", 2
  ensure
    ENV.delete("COACH_TESTERS")
  end

  test "other users don't see the AI Coach link" do
    sign_in users(:one)

    get root_url
    assert_select "a[href='/coach']", count: 0
  end

  test "landing page has a skip link, tagline reveal and FAQ with structured data" do
    get root_url
    assert_select "a.lp-skip[href='#main']"
    assert_select "main#main"
    assert_select "[data-lp-tagline] .lp-tw"
    assert_select "#faq details", 6
    faq = css_select("script[type='application/ld+json']").map { |s| JSON.parse(s.text) }
      .flat_map { |doc| doc["@graph"] }.find { |node| node["@type"] == "FAQPage" }
    assert_equal 6, faq["mainEntity"].size
  end

  test "structured data makes no rating claims" do
    get root_url
    assert_no_match(/aggregateRating/, response.body)
  end

  test "health check returns ok" do
    # Health check doesn't need basic auth
    get "/up"
    assert_response :success
  end
end
