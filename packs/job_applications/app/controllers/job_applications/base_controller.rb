module JobApplications
  # The /my-jobs pages: signed in, and only while Seera Apply is on for the user.
  class BaseController < ApplicationController
    before_action :authenticate_user!, :require_seera_apply!

    private

    def require_seera_apply!
      raise ActionController::RoutingError, "Not Found" unless JobApplications.enabled_for?(current_user)
    end

    def preference
      @preference ||= Preference.find_or_initialize_by(user: current_user)
    end
  end
end
