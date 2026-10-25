require "test_helper"

# Icons render as inline SVG (seera_icon), so no page loads a script from a public CDN.
class NoCdnScriptsTest < ActionDispatch::IntegrationTest
  test "public pages load no CDN scripts and render icons inline" do
    seo = YAML.load_file(Rails.root.join("config/seo_data.yml"))
    city = seo["cities"].first["slug"]
    job = seo["job_titles"].first["slug"]

    [ root_url, login_url, cv_templates_url, cv_template_url(slug: job),
      cv_template_location_url(city_slug: city, job_slug: job), cities_url, city_jobs_url(city_slug: city) ].each do |url|
      get url

      assert_response :success, url
      assert_not_includes response.body, "cdn.jsdelivr.net", url
      assert_not_includes response.body, "<iconify-icon", url
    end
  end
end
