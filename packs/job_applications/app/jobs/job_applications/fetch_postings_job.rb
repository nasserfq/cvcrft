module JobApplications
  # Daily (config/schedule.yml): reads every active employer's public feed,
  # keeps the Gulf postings, closes the ones that disappeared, then matches.
  # One failing feed never stops the run.
  class FetchPostingsJob < ApplicationJob
    queue_as :default

    CLOSED_RETENTION = 90.days
    UNACTED_RETENTION = 60.days
    AI_USAGE_RETENTION = 30.days

    def perform
      # Dark in production until launch.
      return unless JobApplications.enabled_anywhere?

      Employer.where(active: true).order(:id).find_each { |employer| fetch(employer) }
      clean_up
      MatchJob.perform_later
    end

    private

    def fetch(employer)
      fetcher = Fetchers::REGISTRY.fetch(employer.ats) { raise Fetchers::FetchError, "unknown ats #{employer.ats}" }
      postings = fetcher.new(employer).call.uniq(&:external_id)
      now = Time.current

      Posting.transaction do
        if postings.any?
          rows = postings.map do |p|
            p.to_h.merge(employer_id: employer.id, fetched_at: now, closed_at: nil)
          end
          Posting.upsert_all(rows, unique_by: %i[employer_id external_id], update_only: %i[title location country url apply_url description posted_at fetched_at closed_at])
        end
        employer.postings.open.where.not(external_id: postings.map(&:external_id)).update_all(closed_at: now, updated_at: now)
        employer.update!(last_fetched_at: now, last_error: nil)
      end
      Rails.logger.info("[auto_apply] #{employer.ats}/#{employer.identifier}: #{postings.size} Gulf postings")
    rescue StandardError => e
      Rails.logger.error("[auto_apply] fetch failed for #{employer.ats}/#{employer.identifier}: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, tags: { pack: "job_applications", ats: employer.ats })
      employer.update_columns(last_error: "#{e.class}: #{e.message}".first(1_000), updated_at: Time.current)
    end

    # Retention: closed postings nobody applied to, unacted matches, old AI counters.
    def clean_up
      Posting.where(closed_at: ...CLOSED_RETENTION.ago).where.missing(:applications).delete_all
      Application.where(status: %w[queued skipped], created_at: ...UNACTED_RETENTION.ago).delete_all
      AiUsage.where(day: ...AI_USAGE_RETENTION.ago.to_date).delete_all
    end
  end
end
