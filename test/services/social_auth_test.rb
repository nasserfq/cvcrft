require "test_helper"

class SocialAuthTest < ActiveSupport::TestCase
  GOOGLE = { "GOOGLE_CLIENT_ID" => "id", "GOOGLE_CLIENT_SECRET" => "secret" }.freeze
  APPLE = { "APPLE_CLIENT_ID" => "svc", "APPLE_TEAM_ID" => "team", "APPLE_KEY_ID" => "key", "APPLE_PRIVATE_KEY" => "pem" }.freeze
  LINKEDIN = { "LINKEDIN_CLIENT_ID" => "id", "LINKEDIN_CLIENT_SECRET" => "secret" }.freeze

  test "configured lists only providers with every variable set" do
    assert_equal [], SocialAuth.configured({})
    assert_equal [ :google_oauth2 ], SocialAuth.configured(GOOGLE)
    assert_equal [ :google_oauth2, :apple, :linkedin ], SocialAuth.configured(GOOGLE.merge(APPLE, LINKEDIN))
    assert_equal [ :linkedin ], SocialAuth.configured(LINKEDIN.merge(APPLE.except("APPLE_KEY_ID")))
  end

  test "a blank variable counts as missing" do
    assert_equal [], SocialAuth.configured(GOOGLE.merge("GOOGLE_CLIENT_SECRET" => "   "))
    assert_equal [], SocialAuth.configured(LINKEDIN.merge("LINKEDIN_CLIENT_ID" => ""))
  end

  test "apple_private_key decodes a base64 key" do
    pem = "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n"

    assert_equal pem, SocialAuth.apple_private_key(Base64.strict_encode64(pem))
  end

  test "apple_private_key turns a literal \\n PEM into lines" do
    raw = "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----"

    assert_equal "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----", SocialAuth.apple_private_key(raw)
  end

  test "short_name maps provider names" do
    assert_equal "google", SocialAuth.short_name(:google_oauth2)
    assert_equal "apple", SocialAuth.short_name("apple")
    assert_equal "linkedin", SocialAuth.short_name(:linkedin)
  end

  test "the test env turns every provider on" do
    assert_equal SocialAuth::PROVIDERS.keys, SocialAuth.providers
    assert SocialAuth.enabled?("apple")
  end

  test "credentials read the variables, with placeholders in test when blank" do
    assert_equal [ "id", "secret", { scope: "email,profile", prompt: "select_account" } ],
                 SocialAuth.credentials(:google_oauth2, GOOGLE)
    assert_equal [ "test", "test", { scope: "openid profile email" } ], SocialAuth.credentials(:linkedin, {})

    id, secret, options = SocialAuth.credentials(:apple, {})
    assert_equal [ "test", "" ], [ id, secret ]
    assert_equal "", options[:pem]
    assert_equal SocialAuth::APPLE_SETUP, options[:setup]
  end
end
