module JobApplications
  # Scores a user's fresh, unscored postings against their CV. Every score is
  # stored, high or low, so a posting is scored once; the page shows MIN_SCORE and up.
  class Matcher
    BATCH = 5
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

    # Returns how many matches it wrote. Raises AiCircuit::OpenError so the job stops.
    def call
      return 0 unless preference&.ready?

      resume = ResumeBuilder::PublicApi.latest_complete(user)
      return 0 unless resume

      remaining = AiUsage.remaining(user, :scores, DAILY_SCORE_LIMIT)
      return 0 if remaining.zero?

      facts = CvFacts.new(user, resume["id"]).to_prompt
      candidates.first(remaining).each_slice(BATCH).sum { |batch| score(batch, facts) }
    end

    # Open, recently fetched postings in the user's cities whose title shares a word with one of theirs.
    def candidates
      scored = Match.where(user:).select(:posting_id)
      Posting.open.fresh.where(city: preference.cities).where.not(id: scored)
        .includes(:employer).order(Arel.sql("posted_at DESC NULLS LAST"), id: :desc).limit(SCAN_LIMIT)
        .select { |posting| TitleTokens.overlap?(preference.titles, posting.title) }
    end

    private

    def score(batch, facts)
      message = ask(batch, facts)
      return 0 unless message

      rows = Array(JSON.parse(AiModel.json_body(message.content))["scores"])
      write(batch, rows)
    rescue JSON::ParserError, TypeError, NoMethodError => e
      Rails.logger.warn("[seera_apply] matcher could not parse scores for user #{user.id}: #{e.class}: #{e.message}")
      0
    end

    # One AI call. Counted once it has reached the provider, failed or not;
    # an open breaker made no call, so it counts nothing and ends the run.
    def ask(batch, facts)
      message = AiModel.complete(system: SYSTEM_PROMPT, user: prompt(batch, facts), temperature: 0.2, max_tokens: 800)
      AiUsage.bump!(user, :scores, batch.size)
      message
    rescue AiCircuit::OpenError
      raise
    rescue StandardError => e
      AiUsage.bump!(user, :scores, batch.size)
      Rails.logger.error("[seera_apply] matcher AI call failed for user #{user.id}: #{e.class}: #{e.message}")
      nil
    end

    def prompt(batch, facts)
      postings = batch.map do |p|
        { posting_id: p.id, title: p.title, company: p.employer.name, location: p.location, description: p.description.to_s.first(DESCRIPTION_CHARS) }
      end
      "CV facts:\n#{facts}\n\nJobs:\n#{postings.to_json}"
    end

    def write(batch, rows)
      by_id = batch.index_by(&:id)
      records = rows.filter_map do |row|
        posting = by_id.delete(row["posting_id"].to_i) if row.is_a?(Hash)
        next unless posting

        { user_id: user.id, posting_id: posting.id, score: row["score"].to_i.clamp(1, 10),
          score_reason: row["reason"].to_s.squish.first(500).presence }
      end
      return 0 if records.empty?

      Match.insert_all(records, unique_by: %i[user_id posting_id]).length
    end
  end
end
