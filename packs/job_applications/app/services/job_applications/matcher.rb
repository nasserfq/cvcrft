module JobApplications
  # Scores a user's fresh, unseen postings against their CV and queues the good ones.
  class Matcher
    BATCH = 5
    MAX_CANDIDATES = 50
    SCAN_LIMIT = 2_000
    DESCRIPTION_CHARS = 1_500

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You rate how well a candidate fits a job, 1-10. Use only the CV facts given.
      Reply JSON {"scores":[{"posting_id":int,"score":int,"reason":"one sentence"}]}.
    PROMPT

    attr_reader :user, :preference

    def initialize(user)
      @user = user
      @preference = Preference.find_by(user:)
    end

    # Returns how many applications it queued or approved.
    def call
      return 0 unless preference&.consent_accepted? && !preference.paused && preference.titles.any?

      resume = ResumeBuilder::PublicApi.latest_complete(user)
      return 0 unless resume

      remaining = AiUsage.remaining(user, :scores, DAILY_SCORE_LIMIT)
      return 0 if remaining.zero?

      facts = CvFacts.new(user, resume["id"]).to_prompt
      candidates.first(remaining).each_slice(BATCH).sum { |batch| score(batch, facts, resume["id"]) }
    end

    def candidates
      applied = Application.where(user:).select(:posting_id)
      Posting.open.fresh.where(country: preference.countries).where.not(id: applied)
        .includes(:employer).order(Arel.sql("posted_at DESC NULLS LAST"), id: :desc).limit(SCAN_LIMIT)
        .select { |posting| TitleTokens.overlap?(preference.titles, posting.title) }
        .first(MAX_CANDIDATES)
    end

    private

    def score(batch, facts, resume_id)
      # Counted before the call: a failed call still cost a request.
      AiUsage.bump!(user, :scores, batch.size)
      message = AiModel.complete(system: SYSTEM_PROMPT, user: prompt(batch, facts), temperature: 0.2, max_tokens: 800)
      scores = Array(JSON.parse(AiModel.json_body(message.content))["scores"])
      by_id = batch.index_by(&:id)

      scores.sum do |row|
        posting = by_id.delete(row["posting_id"].to_i) if row.is_a?(Hash)
        posting ? create_application(posting, row, resume_id) : 0
      end
    rescue JSON::ParserError, TypeError, NoMethodError => e
      Rails.logger.warn("[auto_apply] matcher could not parse scores for user #{user.id}: #{e.class}: #{e.message}")
      0
    rescue StandardError => e
      Rails.logger.error("[auto_apply] matcher AI call failed for user #{user.id}: #{e.class}: #{e.message}")
      0
    end

    def prompt(batch, facts)
      postings = batch.map do |p|
        { posting_id: p.id, title: p.title, company: p.employer.name, location: p.location, description: p.description.to_s.first(DESCRIPTION_CHARS) }
      end
      "CV facts:\n#{facts}\n\nJobs:\n#{postings.to_json}"
    end

    def create_application(posting, row, resume_id)
      value = row["score"].to_i.clamp(1, 10)
      reason = row["reason"].to_s.squish.first(500).presence
      attrs = if value >= preference.min_score
        { status: preference.mode == "auto" ? "approved" : "queued" }
      else
        # Kept as skipped so the posting is never scored again.
        { status: "skipped", details: { "reason" => "below_min_score" } }
      end
      Application.create!(user:, posting:, resume_id:, score: value, score_reason: reason, **attrs)
      value >= preference.min_score ? 1 : 0
    rescue ActiveRecord::RecordNotUnique
      0
    end
  end
end
