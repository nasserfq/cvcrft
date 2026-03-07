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

  # Set locale before each request
  before_action :set_locale

  # Helper method to get text direction based on locale
  helper_method :text_direction, :current_locale

  # Health check endpoint for Kamal
  def health_check
    render json: { status: "ok", timestamp: Time.current }
  end

  protected

  # Override Devise's authenticate_user! to store intended URL before redirecting to login
  def authenticate_user!
    unless user_signed_in?
      # Store the intended URL so we can redirect back after login
      store_location_for_custom_auth
      redirect_to login_path(return_to: request.fullpath), alert: t("auth.login_required")
      return
    end
  end

  private

  # Store the current URL for redirect after login
  def store_location_for_custom_auth
    session[:user_return_to] = request.fullpath if request.get? && !request.xhr?
  end

  # Set the locale based on: 1) logged-in user preference, 2) cookie, 3) default (ar)
  def set_locale
    locale = extract_locale
    I18n.locale = locale if I18n.available_locales.map(&:to_s).include?(locale)
  end

  def extract_locale
    if user_signed_in? && current_user.locale.present?
      current_user.locale
    elsif cookies[:locale].present?
      cookies[:locale]
    else
      "ar" # Default to Arabic
    end
  end

  def current_locale
    I18n.locale.to_s
  end

  def text_direction
    I18n.locale.to_s == "ar" ? "rtl" : "ltr"
  end
end
