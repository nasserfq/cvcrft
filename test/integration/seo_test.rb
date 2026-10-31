require "test_helper"

class SeoTest < ActionDispatch::IntegrationTest
  test "each language version is its own canonical page with matching hreflang" do
    get "/cv-templates/software-engineer?locale=en"
    assert_select "link[rel=canonical][href='https://cvcrft.com/cv-templates/software-engineer?locale=en']"
    assert_select "link[hreflang=ar][href='https://cvcrft.com/cv-templates/software-engineer']"
    assert_select "link[hreflang=x-default][href='https://cvcrft.com/cv-templates/software-engineer']"

    get "/?locale=ar"
    assert_select "link[rel=canonical][href='https://cvcrft.com/']"
  end

  test "unknown locales fall back to Arabic instead of a third copy" do
    get "/jobs/riyadh?locale=fr"
    assert_response :success
    assert_select "html[lang=ar]"
  end

  test "a trailing slash redirects once to the slashless URL" do
    get "/jobs/?locale=en"
    assert_response :moved_permanently
    assert_equal "/jobs?locale=en", response.location
  end

  test "sitemap lists both languages, and terms only in Arabic" do
    get "/sitemap.xml"
    assert_includes response.body, "<loc>https://cvcrft.com/</loc>"
    assert_includes response.body, "<loc>https://cvcrft.com/jobs?locale=en</loc>"
    assert_includes response.body, "<loc>https://cvcrft.com/terms</loc>"
    assert_not_includes response.body, "terms?locale=en"
  end

  test "the home page links to the template and city pages" do
    get root_url
    assert_select "footer a[href='/cv-templates']"
    assert_select "footer a[href='/jobs']"
  end

  test "build buttons on template pages skip the login redirect for visitors" do
    get "/cv-templates/software-engineer"
    assert_select "a[href='/resumes/new']", count: 0
  end
end
