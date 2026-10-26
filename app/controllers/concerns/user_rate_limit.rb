# Per-account throttles for actions that cost AI calls, PDF renders or money.
# Credits cap how much an account can spend; this caps how fast, so one
# account can't tie up the web workers or the AI provider.
module UserRateLimit
  extend ActiveSupport::Concern

  class_methods do
    # Declare after authenticate_user!, so current_user is known.
    def rate_limit_per_user(to:, within:, only:, name:, with: :render_rate_limited)
      rate_limit to: to, within: within, only: only, name: name,
                 by: -> { current_user&.id || request.remote_ip }, with: with
    end
  end

  private

  def render_rate_limited
    message = t("ux_i18n.rate_limited")
    if request.format.json? || request.xhr?
      render json: { error: message }, status: :too_many_requests
    else
      redirect_back fallback_location: root_path, alert: message
    end
  end
end
