module JobApplications
  # The /auto_apply pages: signed in, and only while the flag is on for the user.
  class BaseController < ApplicationController
    before_action :authenticate_user!, :require_auto_apply!

    private

    def require_auto_apply!
      raise ActionController::RoutingError, "Not Found" unless JobApplications.enabled_for?(current_user)
    end

    def preference
      @preference ||= Preference.find_or_initialize_by(user: current_user)
    end
  end
end
