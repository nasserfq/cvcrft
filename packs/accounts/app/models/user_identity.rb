# A social sign-in account (Google, Apple, LinkedIn) linked to a user.
class UserIdentity < ApplicationRecord
  belongs_to :user

  validates :provider, inclusion: { in: SocialAuth::PROVIDERS.keys.map(&:to_s) }
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
