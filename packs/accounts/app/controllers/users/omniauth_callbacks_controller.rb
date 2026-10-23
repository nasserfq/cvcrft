# Social sign-in callbacks (Google, Apple, LinkedIn). OmniAuth has already
# talked to the provider; SocialSignIn decides who the user is.
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include LoginRedirect

  def google_oauth2 = handle
  def apple = handle
  def linkedin = handle

  # Devise's default sends users to sessions#new, which this app skips.
  def failure
    Rails.logger.info "Social sign-in failed: #{failed_strategy&.name} #{failure_message}"
    redirect_to login_path(return_to: session.delete("social_return_to")), alert: t("social_auth.failed")
  end

  private

  def handle
    auth = request.env["omniauth.auth"]
    # Set by OmniAuth.config.before_request_phase from the login form.
    consent = session.delete("social_privacy_consent") == true
    return_to = session.delete("social_return_to")

    result = SocialSignIn.call(auth, consent:)
    if result.error
      Rails.logger.info "Social sign-in refused: #{auth.provider} #{result.error}"
      return redirect_to(login_path(return_to:), alert: error_message(result.error))
    end

    sign_in(:user, result.user)
    Rails.logger.info "User #{result.user.id} signed in with #{auth.provider}"
    identify_user(result.user)
    track_event("user_logged_in", { login_method: SocialAuth.short_name(auth.provider), new_user: result.created })
    redirect_to safe_return_to(return_to) || new_resume_path, notice: t("ux_i18n.auth.signed_in")
  end

  def error_message(error)
    error == :consent_required ? t("pdpl_consent.required") : t("social_auth.errors.#{error}")
  end
end
