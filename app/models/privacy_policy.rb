# The version of the privacy policy and terms a user accepts at login.
# Bump VERSION (an ISO date) whenever the policy changes materially; the
# privacy page shows it as the "last updated" date.
module PrivacyPolicy
  VERSION = "2026-10-19"

  def self.last_updated = Date.iso8601(VERSION)
end
