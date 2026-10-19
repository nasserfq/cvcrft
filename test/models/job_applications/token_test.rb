require "test_helper"

class JobApplications::TokenTest < ActiveSupport::TestCase
  test "issue! stores only the digest and returns the raw token once" do
    token, raw = JobApplications::Token.issue!(users(:one))

    assert raw.start_with?("seera_")
    assert_equal OpenSSL::Digest::SHA256.hexdigest(raw), token.token_digest
    assert_not_includes token.attributes.values.map(&:to_s), raw
  end

  test "issuing a new token revokes the old one" do
    old, old_raw = JobApplications::Token.issue!(users(:one))
    other, = JobApplications::Token.issue!(users(:two))
    _new, new_raw = JobApplications::Token.issue!(users(:one))

    assert old.reload.revoked_at.present?
    assert_nil other.reload.revoked_at
    assert_equal 1, JobApplications::Token.where(user: users(:one)).active.count
    assert_nil JobApplications::Token.authenticate(old_raw)
    assert_equal users(:one), JobApplications::Token.authenticate(new_raw).user
  end

  test "authenticate ignores revoked, blank and unknown tokens" do
    token, raw = JobApplications::Token.issue!(users(:one))
    token.update!(revoked_at: Time.current)

    assert_nil JobApplications::Token.authenticate(raw)
    assert_nil JobApplications::Token.authenticate(nil)
    assert_nil JobApplications::Token.authenticate("")
    assert_nil JobApplications::Token.authenticate("seera_nope")
  end
end
