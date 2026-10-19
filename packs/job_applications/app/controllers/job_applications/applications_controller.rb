module JobApplications
  # Approve / Skip in the review queue, Delete in the tracker. Only the user's own rows.
  class ApplicationsController < BaseController
    before_action :set_application

    def approve
      return invalid_transition unless @application.status == "queued"

      @application.update!(status: "approved")
      redirect_to auto_apply_root_path(anchor: "queue"), notice: t("auto_apply.flash.approved")
    end

    def skip
      return invalid_transition unless %w[queued approved needs_user].include?(@application.status)

      @application.update!(status: "skipped", finished_at: Time.current)
      redirect_to auto_apply_root_path(anchor: "queue"), notice: t("auto_apply.flash.skipped")
    end

    def destroy
      @application.destroy!
      redirect_to auto_apply_root_path(anchor: "tracker"), notice: t("auto_apply.flash.deleted")
    end

    private

    def set_application
      @application = Application.where(user: current_user).find(params[:id])
    end

    def invalid_transition
      redirect_to auto_apply_root_path, alert: t("auto_apply.flash.invalid_transition")
    end
  end
end
