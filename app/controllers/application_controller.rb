class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Basic HTTP Authentication
  http_basic_authenticate_with name: ENV["BASIC_AUTH_USERNAME"] || "admin",
                              password: ENV["BASIC_AUTH_PASSWORD"] || "cvcraft2024"

  # Include Devise helpers for authentication
  include Devise::Controllers::Helpers

  # Make Devise helpers available in views
  helper_method :user_signed_in?, :current_user

  # Health check endpoint for Kamal
  def health_check
    render json: { status: "ok", timestamp: Time.current }
  end
end
