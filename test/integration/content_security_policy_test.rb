require "test_helper"

# The enforced Content-Security-Policy from config/initializers/content_security_policy.rb.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  HEADER = "Content-Security-Policy".freeze

  def directives
    policy = response.headers[HEADER]
    assert policy.present?, "#{request.path} has no #{HEADER} header"
    assert_nil response.headers["#{HEADER}-Report-Only"], "policy must be enforced, not report-only"

    policy.split(";").to_h do |directive|
      name, *sources = directive.split
      [ name, sources ]
    end
  end

  test "logged-out pages carry the enforced policy" do
    [ root_path, "/login" ].each do |path|
      get path
      assert_response :success
      d = directives

      assert_equal [ "'self'" ], d["default-src"]
      assert_includes d["script-src"], "'unsafe-inline'"
      assert_includes d["style-src"], "https://fonts.googleapis.com"
      assert_includes d["font-src"], "https://fonts.gstatic.com"
      assert_includes d["connect-src"], "'self'"
      assert_includes d["script-src"], "https://static.cloudflareinsights.com"
      assert_includes d["connect-src"], "https://cloudflareinsights.com"
      assert_equal [ "'none'" ], d["object-src"]
      assert_equal [ "'self'" ], d["base-uri"]
      assert_equal [ "'self'" ], d["frame-ancestors"]
      %w[https://accounts.google.com https://appleid.apple.com https://checkout.moyasar.com].each do |host|
        assert_includes d["form-action"], host
      end
    end
  end

  test "no nonce or eval, which would switch off unsafe-inline or open eval" do
    get root_path
    policy = response.headers[HEADER]

    assert_no_match(/'nonce-/, policy)
    assert_no_match(/'unsafe-eval'/, policy)
  end

  test "signed-in pages carry the policy; only /cv_generations/new may load from unpkg" do
    user = users(:one)
    create_test_resume(user)
    Coach.stubs(:enabled_for?).returns(true)
    Billing.stubs(:enabled_for?).returns(true)
    sign_in user

    [ new_resume_path, "/coach", "/credits", cv_generations_path ].each do |path|
      get path
      assert_not_includes directives["script-src"], "https://unpkg.com", path
    end

    get new_cv_generation_path
    assert_response :success
    assert_includes directives["script-src"], "https://unpkg.com"
    assert_not_includes directives["script-src"], "'unsafe-eval'"
  end
end
