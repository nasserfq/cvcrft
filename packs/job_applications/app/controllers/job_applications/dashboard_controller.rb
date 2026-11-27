module JobApplications
  # "Jobs for you": build a CV, then pick titles and cities, then the matches.
  # Once set up for applying, the switch and the application tracker sit on top.
  class DashboardController < BaseController
    LIMIT = 100
    TABS = {
      "queued" => %w[preparing queued sending],
      "approval" => %w[needs_approval],
      "answer" => %w[needs_answer],
      "sent" => %w[sent],
      "failed" => %w[failed_fallback]
    }.freeze
    DEFAULT_TABS = %w[answer approval queued].freeze

    def show
      @resume = ResumeBuilder::PublicApi.latest_complete(current_user)
      @preference = preference
      scope = Match.shown.where(user: current_user)
      @count = scope.count
      @matches = scope.includes(posting: :employer).order(score: :desc, "apply_postings.posted_at": :desc).limit(LIMIT)
      load_tracker if @resume && @preference.ready?
    end

    private

    def load_tracker
      @profile = Profile.find_by(user: current_user)
      return unless @profile

      by_status = Application.where(user: current_user).group(:status).count
      @tab_counts = TABS.transform_values { |statuses| statuses.sum { |status| by_status.fetch(status, 0) } }
      @tab = TABS.key?(params[:tab]) ? params[:tab] : default_tab
      @applications = Application.where(user: current_user, status: TABS.fetch(@tab))
        .includes(posting: :employer).order(updated_at: :desc, id: :desc).limit(LIMIT).to_a
      # Which rows have which documents, without loading the bytes.
      @document_kinds = Document.where(application_id: @applications.map(&:id)).pluck(:application_id, :kind)
        .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    end

    def default_tab
      (DEFAULT_TABS + TABS.keys).find { |tab| @tab_counts[tab].positive? } || "queued"
    end
  end
end
