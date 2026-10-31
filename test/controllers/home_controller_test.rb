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
    assert_select "[data-testid=pricing-table] tbody td:first-of-type", 5 do |cells|
      assert_equal [ I18n.t("home_landing.pricing.unlimited", locale: :ar), "10", "20", "20", Coach::FREE_MESSAGES.to_s ], cells.map { _1.text.strip }
    end
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

  test "landing page has a skip link, tagline reveal and FAQ without FAQ schema" do
    get root_url
    assert_select "a.lp-skip[href='#main']"
    assert_select "main#main"
    assert_select "[data-lp-tagline] .lp-tw"
    assert_select "#faq details", 6
    # Google stopped showing FAQ rich results, so the markup is dead weight.
    types = css_select("script[type='application/ld+json']").map { |s| JSON.parse(s.text) }
      .flat_map { |doc| doc["@graph"] }.map { |node| node["@type"] }
    assert_not_includes types, "FAQPage"
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

# Logged-out visitors get the landing's static parts from the cache.
class HomeControllerCacheTest < ActionDispatch::IntegrationTest
  setup do
    @caching, @store = ActionController::Base.perform_caching, ActionController::Base.cache_store
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.perform_caching = true
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    ActionController::Base.perform_caching = @caching
    ActionController::Base.cache_store = @store
    ActionController::Base.allow_forgery_protection = @forgery
  end

  test "a second logged-out visit serves the cached landing" do
    get "/login" # a session, so the header carries a token
    assert_equal 1, footer_renders { get root_url }
    first = response.body

    User.expects(:count).never
    assert_equal 0, footer_renders { get root_url }
    assert_select "#faq details", 6
    assert_select "header form input[name=authenticity_token]"
    assert_equal without_tokens(first), without_tokens(response.body)
  end

  test "a logged-in visit is not served the logged-out copy" do
    get root_url
    sign_in users(:one)

    assert_equal 1, footer_renders { get root_url }
    assert_select "a[href=?]", new_resume_path
    assert_select "a[href=?]", login_path(return_to: new_resume_path), 0
  end

  test "Arabic and English get their own cached copies" do
    assert_equal 1, footer_renders { get root_url(locale: "en") }
    assert_equal 1, footer_renders { get root_url(locale: "ar") }

    assert_equal 0, footer_renders { get root_url(locale: "en") }
    assert_select "html[lang=en]"
    assert_select "#faq h3", text: I18n.t("home_landing.faq.q1", locale: :en)
    assert_equal 0, footer_renders { get root_url(locale: "ar") }
    assert_select "html[lang=ar]"
    assert_select "#faq h3", text: I18n.t("home_landing.faq.q1", locale: :ar)
  end

  test "a first visit is public for a minute and sets no cookie" do
    get root_url
    assert_equal "max-age=0, public, s-maxage=60", response.headers["Cache-Control"]
    assert_nil response.headers["Set-Cookie"]
    assert_select "meta[name=csrf-token]", 0
    assert_select "#consent-banner[hidden]"
    assert_select "header a[href='/?locale=en']"
    assert_select "header form[action='/locale/en']", 0
  end

  test "the consent cookie alone keeps the page public, banner still in the markup" do
    cookies[:analytics_consent] = "granted"
    get root_url
    assert_includes response.headers["Cache-Control"], "public"
    assert_select "#consent-banner[hidden]"
  end

  test "a visitor with a session, a language or a query string gets a private page" do
    get "/login"
    get root_url
    assert_includes response.headers["Cache-Control"], "private"
    assert_select "meta[name=csrf-token]"

    reset!
    get root_url(locale: "en")
    assert_includes response.headers["Cache-Control"], "private"
    assert_match(/locale=en/, response.headers["Set-Cookie"].to_s)
    get root_url
    assert_includes response.headers["Cache-Control"], "private"

    reset!
    sign_in users(:one)
    get root_url
    assert_includes response.headers["Cache-Control"], "private"
  end

  private

  # Tokens are masked afresh on every request.
  def without_tokens(html)
    html.gsub(/(csrf-token" content|authenticity_token" value)="[^"]+"/, '\\1=""')
  end

  def footer_renders(&request)
    count = 0
    counter = ->(event) { count += 1 if event.payload[:identifier].end_with?("shared/_site_footer.html.erb") }
    ActiveSupport::Notifications.subscribed(counter, "render_partial.action_view", &request)
    count
  end
end
