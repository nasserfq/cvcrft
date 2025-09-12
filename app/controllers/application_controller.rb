class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Include Devise helpers for authentication
  include Devise::Controllers::Helpers
  
  # Make Devise helpers available in views
  helper_method :user_signed_in?, :current_user
end
