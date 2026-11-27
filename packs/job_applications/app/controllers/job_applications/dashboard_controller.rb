module JobApplications
  # "Jobs for you": build a CV, then pick titles and cities, then the matches.
  class DashboardController < BaseController
    LIMIT = 100

    def show
      @resume = ResumeBuilder::PublicApi.latest_complete(current_user)
      @preference = preference
      scope = Match.shown.where(user: current_user)
      @count = scope.count
      @matches = scope.includes(posting: :employer).order(score: :desc, "apply_postings.posted_at": :desc).limit(LIMIT)
    end
  end
end
