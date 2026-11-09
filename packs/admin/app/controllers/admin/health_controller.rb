# Read-only Health page: Postgres and Redis reachability, the AI work SLIs
# against their SLOs, and Sidekiq queue, retry and dead counts. Counts only.
module Admin
  class HealthController < Admin::ApplicationController
    def show
      @checks = HealthProbe.call
      @work = ServiceLevels.ai_work
      @breaches = ServiceLevels.ai_breaches(@work)
      @sidekiq = ServiceLevels.sidekiq
    end
  end
end
