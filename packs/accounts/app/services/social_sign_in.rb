# Decides who a social sign-in (Google, Apple, LinkedIn) belongs to: the user
# already linked to that provider account, else the user with that verified
# email, else a new user. No HTTP and no session work, so the rules are easy
# to test; Users::OmniauthCallbacksController turns the result into a login.
class SocialSignIn
  # error is one of :no_email, :email_unverified, :consent_required, :invalid.
  Result = Struct.new(:user, :error, :created, keyword_init: true)

  # Providers that put email_verified in raw_info. Apple only returns verified
  # addresses (private relay included), so it is always trusted.
  VERIFIED_EMAIL_PROVIDERS = %w[google_oauth2 linkedin].freeze

  def self.call(auth, consent:, locale: I18n.locale)
    new(auth, consent:, locale:).call
  end

  def initialize(auth, consent:, locale:)
    @auth = auth
    @consent = consent
    @locale = locale
  end

  def call
    identity = find_identity
    return finish(identity.user) if identity
    return error(:no_email) if email.blank?
    # An unverified email never creates or links an account: it would squat on
    # someone else's address, and their OTP login would land in this account.
    return error(:email_unverified) unless email_verified?

    user = User.find_by("LOWER(email) = ?", email)
    return error(:consent_required) unless consent || user&.privacy_accepted_at

    created = user.nil?
    User.transaction do
      user ||= User.create!(email:, name: display_name, locale: locale_string, password:, password_confirmation: password)
      user.identities.create!(provider:, uid:, email:)
    end
    finish(user, created:)
  rescue ActiveRecord::RecordNotUnique
    # A double-clicked callback: the other request linked it first.
    identity = find_identity
    identity ? finish(identity.user) : error(:invalid)
  rescue ActiveRecord::RecordInvalid
    error(:invalid)
  end

  private

  attr_reader :auth, :consent, :locale

  def find_identity
    UserIdentity.find_by(provider:, uid:)
  end

  # Same rule as OTP: no consent, no login, unless it was recorded before.
  def finish(user, created: false)
    if consent
      user.record_privacy_consent!
    elsif user.privacy_accepted_at.nil?
      return error(:consent_required)
    end
    Result.new(user:, created:)
  end

  def error(code)
    Result.new(error: code, created: false)
  end

  def provider
    auth.provider.to_s
  end

  def uid
    auth.uid.to_s
  end

  def email
    @email ||= String(auth.info&.email).strip.downcase
  end

  def email_verified?
    return true if provider == "apple"
    return false unless VERIFIED_EMAIL_PROVIDERS.include?(provider)

    [ true, "true" ].include?(auth.extra&.raw_info&.email_verified)
  end

  def display_name
    info = auth.info
    candidates = [ info&.name, [ info&.first_name, info&.last_name ].join(" "), email.split("@").first ]
    name = candidates.map { |c| c.to_s.strip }.find { |c| c.length >= 2 }
    name ? name.truncate(100, omission: "").strip : I18n.t("social_auth.default_name", locale: locale_string)
  end

  def locale_string
    %w[ar en].include?(locale.to_s) ? locale.to_s : "ar"
  end

  def password
    @password ||= SecureRandom.hex(16)
  end
end
