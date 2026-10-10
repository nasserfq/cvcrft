class LocalesController < ApplicationController
  AVAILABLE_LOCALES = %w[ar en].freeze

  def update
    locale = params[:locale].to_s

    if AVAILABLE_LOCALES.include?(locale)
      # Save to cookie for all users
      cookies[:locale] = {
        value: locale,
        expires: 1.year.from_now,
        httponly: true
      }

      # Save to user profile if logged in
      if user_signed_in?
        current_user.update(locale: locale)
      end

      I18n.locale = locale
    end

    # Redirect back or to root
    redirect_back(fallback_location: root_path)
  end
end
