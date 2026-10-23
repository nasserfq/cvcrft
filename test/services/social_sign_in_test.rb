require "test_helper"

class SocialSignInTest < ActiveSupport::TestCase
  def auth(provider: "google_oauth2", uid: "uid-#{SecureRandom.hex(4)}", email: "new-#{SecureRandom.hex(4)}@example.com",
           name: "Sara Ahmed", first_name: nil, last_name: nil, verified: true)
    OmniAuth::AuthHash.new(provider:, uid:,
                           info: { email:, name:, first_name:, last_name: },
                           extra: { raw_info: { email_verified: verified } })
  end

  test "a new Google user with consent gets an account, an identity and a consent record" do
    hash = auth

    result = nil
    assert_difference [ "User.count", "UserIdentity.count" ], 1 do
      result = SocialSignIn.call(hash, consent: true, locale: :en)
    end

    assert_nil result.error
    assert result.created
    user = result.user
    assert_equal hash.info.email, user.email
    assert_equal "Sara Ahmed", user.name
    assert_equal "en", user.locale
    assert_not_nil user.privacy_accepted_at
    assert_equal PrivacyPolicy::VERSION, user.privacy_policy_version
    assert_equal [ [ "google_oauth2", hash.uid, hash.info.email ] ], user.identities.pluck(:provider, :uid, :email)
  end

  test "a new user without consent is refused and nothing is created" do
    assert_no_difference [ "User.count", "UserIdentity.count" ] do
      result = SocialSignIn.call(auth, consent: false)
      assert_equal :consent_required, result.error
      assert_nil result.user
    end
  end

  test "a verified email links the existing account, ignoring case" do
    user = users(:one)

    result = nil
    assert_no_difference "User.count" do
      assert_difference "UserIdentity.count", 1 do
        result = SocialSignIn.call(auth(email: user.email.upcase), consent: true)
      end
    end

    assert_equal user, result.user
    assert_not result.created
    assert_equal 1, user.identities.count
  end

  test "an unverified LinkedIn email never creates or links an account" do
    existing = users(:one)

    assert_no_difference [ "User.count", "UserIdentity.count" ] do
      [ existing.email, "nobody-#{SecureRandom.hex(4)}@example.com" ].each do |email|
        result = SocialSignIn.call(auth(provider: "linkedin", email:, verified: false), consent: true)
        assert_equal :email_unverified, result.error
      end
      result = SocialSignIn.call(auth(provider: "linkedin", verified: "false"), consent: true)
      assert_equal :email_unverified, result.error
    end
  end

  test "a string true email_verified counts as verified" do
    result = SocialSignIn.call(auth(provider: "linkedin", verified: "true"), consent: true)

    assert_nil result.error
    assert result.created
  end

  test "a returning Apple user is found by uid without an email" do
    first = SocialSignIn.call(auth(provider: "apple", uid: "apple-123", verified: nil), consent: true)
    assert first.created

    result = nil
    assert_no_difference [ "User.count", "UserIdentity.count" ] do
      result = SocialSignIn.call(auth(provider: "apple", uid: "apple-123", email: nil, name: nil), consent: false)
    end

    assert_nil result.error
    assert_equal first.user, result.user
    assert_not result.created
  end

  test "no email and no identity is refused" do
    result = SocialSignIn.call(auth(email: ""), consent: true)

    assert_equal :no_email, result.error
  end

  test "a one-letter or blank name falls back to the email prefix" do
    [ "A", "   " ].each do |name|
      email = "prefix#{SecureRandom.hex(3)}@example.com"
      result = SocialSignIn.call(auth(email:, name:), consent: true)
      assert_equal email.split("@").first, result.user.name
    end
  end

  test "first and last name are used when the full name is missing" do
    result = SocialSignIn.call(auth(name: nil, first_name: "Nora", last_name: "Saleh"), consent: true)

    assert_equal "Nora Saleh", result.user.name
  end

  test "a very long name is cut to 100 characters" do
    result = SocialSignIn.call(auth(name: "N" * 300), consent: true)

    assert_equal 100, result.user.name.length
  end

  test "an unknown locale falls back to Arabic" do
    result = SocialSignIn.call(auth, consent: true, locale: :fr)

    assert_equal "ar", result.user.locale
  end

  test "a user who never consented and arrives without consent is refused" do
    user = users(:one)
    user.update_columns(privacy_accepted_at: nil)
    user.identities.create!(provider: "google_oauth2", uid: "g-1", email: user.email)

    result = SocialSignIn.call(auth(uid: "g-1", email: user.email), consent: false)

    assert_equal :consent_required, result.error
  end

  test "a user who consented before can sign in without the box" do
    user = users(:one)
    user.record_privacy_consent!

    result = SocialSignIn.call(auth(email: user.email), consent: false)

    assert_nil result.error
    assert_equal user, result.user
  end

  test "a duplicate identity from a double-clicked callback finishes with that identity" do
    user = users(:one)
    user.identities.create!(provider: "google_oauth2", uid: "dup-1", email: user.email)
    UserIdentity.stubs(:find_by).returns(nil).then.returns(user.identities.first)
    UserIdentity.any_instance.stubs(:save!).raises(ActiveRecord::RecordNotUnique)

    result = SocialSignIn.call(auth(uid: "dup-1", email: user.email), consent: true)

    assert_nil result.error
    assert_equal user, result.user
  end
end
