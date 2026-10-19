module JobApplications
  class DashboardController < BaseController
    TRACKER_LIMIT = 100

    def show
      @preference = preference
      @token = Token.where(user: current_user).active.order(created_at: :desc).first
      @new_token = flash[:auto_apply_token]
      @resume = ResumeBuilder::PublicApi.latest_complete(current_user)
      scope = Application.where(user: current_user).includes(posting: :employer)
      @queue = scope.where(status: "queued").order(score: :desc, created_at: :desc)
      @applications = scope.where.not(status: "queued").order(created_at: :desc, id: :desc).limit(TRACKER_LIMIT)
      @today = JobApplications.today(current_user, @preference.persisted? ? @preference : nil)
      @daily_remaining = @today["remaining"]
    end
  end
end
