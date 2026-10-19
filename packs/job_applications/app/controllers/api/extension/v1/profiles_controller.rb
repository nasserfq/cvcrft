module Api
  module Extension
    module V1
      # The CV fields the extension fills forms with.
      class ProfilesController < BaseController
        before_action :require_consent!

        def show
          return error(:not_found, :not_found) unless latest_resume

          render json: JobApplications::CvFacts.new(current_user, latest_resume["id"], preference:).profile
        end
      end
    end
  end
end
