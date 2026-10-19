module Api
  module Extension
    module V1
      # The newest finished CV as a PDF, for the apply form's file input.
      class ResumesController < BaseController
        before_action :require_consent!

        def show
          return error(:not_found, :not_found) unless latest_resume

          pdf = ResumeBuilder::PublicApi.pdf(current_user, latest_resume["id"])
          send_data pdf[:data], filename: pdf[:filename], type: "application/pdf", disposition: "attachment"
        rescue ActiveRecord::RecordNotFound
          error(:not_found, :not_found)
        rescue StandardError => e
          Rails.logger.error("[auto_apply] resume PDF failed for user #{current_user.id}: #{e.class}: #{e.message}")
          error(:service_unavailable, :pdf_failed)
        end
      end
    end
  end
end
