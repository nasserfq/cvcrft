module JobApplications
  # The extension's pairing token. Only its SHA256 digest is stored.
  class Token < ApplicationRecord
    belongs_to :user

    scope :active, -> { where(revoked_at: nil) }

    # Revokes the user's existing tokens and returns [token, raw]; raw is shown once.
    def self.issue!(user)
      transaction do
        where(user:).active.update_all(revoked_at: Time.current, updated_at: Time.current)
        raw = "seera_" + SecureRandom.urlsafe_base64(32)
        [ create!(user:, token_digest: digest(raw)), raw ]
      end
    end

    def self.digest(raw) = OpenSSL::Digest::SHA256.hexdigest(raw.to_s)

    def self.authenticate(raw)
      return nil if raw.blank?

      active.find_by(token_digest: digest(raw))
    end
  end
end
