require "sidekiq/api"

# Service level indicators (SLIs) for the async AI work and Sidekiq, and the
# objectives (SLOs) they are held to. Read by the admin Health page and by
# SloCheckJob, which tells Sentry when one is missed. Counts and timings only:
# nothing here names a user.
module ServiceLevels
  WINDOWS = { "24h" => 24.hours, "7d" => 7.days }.freeze

  # AI jobs: at least 98% of the work started in the last 24 h that finished
  # succeeded. Not judged on fewer than 20 finished, where one failure is 5%.
  AI_SUCCESS_TARGET = 0.98
  AI_SUCCESS_WINDOW = "24h"
  AI_SUCCESS_MIN_FINISHED = 20

  # Site uptime, measured by UptimeRobot on /up. Shown on the Health page only.
  UPTIME_TARGET = 0.995

  # Async kinds with a status column: name => model. Cancelled and unfinished
  # rows count as neither completed nor failed. Duration is updated_at minus
  # created_at of completed rows.
  STATUS_KINDS = {
    "cv_generations" => "CvGeneration",
    "cv_analyses" => "CvAnalysis",
    "ai_translations" => "AiTranslation",
    "cv_imports" => "CvImport",
    "linkedin_imports" => "LinkedinImport"
  }.freeze
  COACH_KIND = "coach_turns"
  KINDS = [ *STATUS_KINDS.keys, COACH_KIND ].freeze

  STATUS_COLUMNS = [
    "COUNT(*) FILTER (WHERE status = 'completed')",
    "COUNT(*) FILTER (WHERE status = 'failed')",
    "PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM updated_at - created_at)) " \
    "FILTER (WHERE status = 'completed')",
    "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM updated_at - created_at)) " \
    "FILTER (WHERE status = 'completed')"
  ].map { |sql| Arel.sql(sql) }.freeze

  # Coach has no status column (docs/state-machines.md, "Coach turn"). A user
  # message is a turn: completed when an assistant reply follows it before the
  # next user message, failed when it has none and ended (end_turn!) or ran
  # past the turn timeout. Duration runs to that reply.
  COACH_SQL = <<~SQL.squish.freeze
    SELECT
      COUNT(reply.created_at),
      COUNT(*) FILTER (WHERE reply.created_at IS NULL AND (turn.updated_at > turn.created_at OR turn.created_at < :timed_out_before)),
      PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM reply.created_at - turn.created_at)),
      PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM reply.created_at - turn.created_at))
    FROM coach_messages turn
    LEFT JOIN LATERAL (
      SELECT answer.created_at FROM coach_messages answer
      WHERE answer.coach_chat_id = turn.coach_chat_id AND answer.role = 'assistant'
        AND answer.created_at >= turn.created_at
        AND NOT EXISTS (
          SELECT 1 FROM coach_messages later
          WHERE later.coach_chat_id = turn.coach_chat_id AND later.role = 'user'
            AND later.created_at > turn.created_at AND later.created_at < answer.created_at
        )
      ORDER BY answer.created_at LIMIT 1
    ) reply ON TRUE
    WHERE turn.role = 'user' AND turn.created_at >= :since
  SQL

  module_function

  # => { "24h" => { "cv_generations" => { completed:, failed:, success_rate:, p50:, p95: }, ... }, "7d" => ... }
  def ai_work(now: Time.current)
    WINDOWS.transform_values do |length|
      since = now - length
      KINDS.index_with { |kind| kind_stats(kind, since, now) }
    end
  end

  # => { enqueued:, retry:, dead:, queues: { "default" => 0, ... } }, or nil when Redis is down.
  def sidekiq
    stats = Sidekiq::Stats.new
    { enqueued: stats.enqueued, retry: stats.retry_size, dead: stats.dead_size, queues: stats.queues }
  rescue StandardError => e
    Rails.logger.warn("[ServiceLevels] Sidekiq stats unavailable: #{e.class}")
    nil
  end

  # Kinds whose 24 h success rate is below AI_SUCCESS_TARGET with enough
  # finished work to judge. => { "cv_analyses" => { completed:, failed:, ... } }
  def ai_breaches(work = ai_work)
    work.fetch(AI_SUCCESS_WINDOW).select do |_kind, stats|
      finished = stats[:completed] + stats[:failed]
      finished >= AI_SUCCESS_MIN_FINISHED && stats[:success_rate] < AI_SUCCESS_TARGET
    end
  end

  def kind_stats(kind, since, now)
    row = kind == COACH_KIND ? coach_row(since, now) : status_row(STATUS_KINDS.fetch(kind).constantize, since)
    completed, failed, p50, p95 = row || [ 0, 0, nil, nil ]
    finished = completed + failed

    {
      completed: completed,
      failed: failed,
      success_rate: finished.zero? ? nil : completed.fdiv(finished),
      p50: p50&.to_f&.round(1),
      p95: p95&.to_f&.round(1)
    }
  end

  def status_row(model, since)
    relation = model.unscoped
    # Legacy builder-export rows never ran the AI.
    relation = relation.ai_generated if model.respond_to?(:ai_generated)
    relation.where(created_at: since..).pick(*STATUS_COLUMNS)
  end

  def coach_row(since, now)
    sql = ActiveRecord::Base.sanitize_sql_array([ COACH_SQL, { since: since, timed_out_before: now - Coach::Chat::TURN_TIMEOUT } ])
    ActiveRecord::Base.connection.select_rows(sql).first&.then do |completed, failed, p50, p95|
      [ completed.to_i, failed.to_i, p50, p95 ]
    end
  end
end
