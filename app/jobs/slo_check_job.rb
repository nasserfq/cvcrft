# Hourly (config/schedule.yml): sends Sentry a warning for each AI kind whose
# 24 h success rate is below ServiceLevels::AI_SUCCESS_TARGET, and when the
# Sidekiq Dead set grew since the last run. Each warning's fingerprint carries
# the date, so a miss opens at most one new Sentry issue (and one email) a day.
class SloCheckJob < ApplicationJob
  queue_as :default

  DEAD_COUNT_KEY = "slo_check_job/dead_count"

  def perform
    breaches = ServiceLevels.ai_breaches
    breaches.each { |kind, stats| report_ai_breach(kind, stats) }
    dead_grew = check_dead_jobs

    Rails.logger.info "[SloCheckJob] ai_breaches=#{breaches.keys.join(',').presence || 'none'} dead_grew=#{dead_grew}"
    { ai_breaches: breaches.keys, dead_grew: dead_grew }
  end

  private

  def report_ai_breach(kind, stats)
    rate = (stats[:success_rate] * 100).round(1)
    target = (ServiceLevels::AI_SUCCESS_TARGET * 100).round(1)

    Sentry.capture_message(
      "SLO missed: #{kind} success #{rate}% < #{target}% over #{ServiceLevels::AI_SUCCESS_WINDOW}",
      level: :warning,
      tags: { slo: "ai_success", kind: kind },
      extra: stats.slice(:completed, :failed, :p50, :p95),
      fingerprint: [ "slo-ai-success", kind, Date.current.iso8601 ]
    )
  end

  # The first run only records the count. Returns whether it grew.
  def check_dead_jobs
    sidekiq = ServiceLevels.sidekiq
    return false unless sidekiq

    dead = sidekiq[:dead]
    previous = Rails.cache.read(DEAD_COUNT_KEY)
    Rails.cache.write(DEAD_COUNT_KEY, dead)
    return false unless previous && dead > previous

    Sentry.capture_message(
      "Sidekiq dead jobs grew from #{previous} to #{dead}",
      level: :warning,
      tags: { slo: "dead_jobs" },
      fingerprint: [ "slo-dead-jobs", Date.current.iso8601 ]
    )
    true
  end
end
