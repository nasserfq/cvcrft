class SocialAuthController < ApplicationController
  # Apple posts here cross-site (response_mode=form_post); no session cookie or
  # CSRF token arrives. Bounce to a same-site GET so the Lax session cookie is
  # sent and OmniAuth's state check can run.
  skip_forgery_protection only: :apple_form_post

  APPLE_PARAMS = %w[code state id_token user error].freeze

  def apple_form_post
    return head :not_found unless SocialAuth.enabled?(:apple)

    query = request.request_parameters.slice(*APPLE_PARAMS).to_query
    redirect_to "#{user_apple_omniauth_callback_path}?#{query}", status: :see_other
  end
end
