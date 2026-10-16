class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Basic HTTP Authentication (skip for health check)
  # http_basic_authenticate_with name: ENV["BASIC_AUTH_USERNAME"] || "admin",
  #                             password: ENV["BASIC_AUTH_PASSWORD"] || "cvcraft2024",
  #                             except: [ :health_check ]

  # Include Devise helpers for authentication
  include Devise::Controllers::Helpers

  # Include PostHog tracking
  include PosthogTrackable

  # Make Devise helpers available in views
  helper_method :user_signed_in?, :current_user

  # Run each request in its locale, restoring the previous one afterwards so it
  # cannot leak into the next request served by the same thread
  around_action :switch_locale

  # Helper method to get text direction based on locale
  helper_method :text_direction, :current_locale

  # Health check endpoint for Kamal
  def health_check
    render json: { status: "ok", timestamp: Time.current }
  end

  protected

  # Override Devise's authenticate_user! to store intended URL before redirecting to login
  def authenticate_user!
    return if user_signed_in?

    # JSON callers (the React components today, a mobile client later) can't
    # follow a redirect to an HTML login page — they'd parse the page as JSON.
    if request.format.json? || request.xhr?
      render json: { error: t("auth.login_required"), authenticated: false }, status: :unauthorized
      return
    end

    # Store the intended URL so we can redirect back after login
    store_location_for_custom_auth
    redirect_to login_path(return_to: request.fullpath), alert: t("auth.login_required")
  end

  private

  # Store the current URL for redirect after login
  def store_location_for_custom_auth
    session[:user_return_to] = request.fullpath if request.get? && !request.xhr?
  end

  # Set the locale based on: 1) logged-in user preference, 2) cookie, 3) default (ar)
  def switch_locale(&action)
    locale = extract_locale
    persist_locale_preference(locale)
    return yield unless valid_locale?(locale)

    I18n.with_locale(locale, &action)
  end

  def extract_locale
    requested_locale = params[:locale].to_s
    return requested_locale if valid_locale?(requested_locale)

    cookie_locale = cookies[:locale].to_s
    return cookie_locale if valid_locale?(cookie_locale)

    user_locale = current_user&.locale.to_s
    return user_locale if valid_locale?(user_locale)

    "ar" # Default to Arabic
  end

  def persist_locale_preference(locale)
    return unless valid_locale?(locale)

    if cookies[:locale] != locale
      cookies[:locale] = {
        value: locale,
        expires: 1.year.from_now,
        httponly: true
      }
    end

    return unless user_signed_in?
    return if current_user.locale == locale

    current_user.update_column(:locale, locale)
  end

  def valid_locale?(locale)
    available_locale_strings.include?(locale)
  end

  def available_locale_strings
    @available_locale_strings ||= I18n.available_locales.map(&:to_s)
  end

  def current_locale
    I18n.locale.to_s
  end

  def text_direction
    I18n.locale.to_s == "ar" ? "rtl" : "ltr"
  end
end
