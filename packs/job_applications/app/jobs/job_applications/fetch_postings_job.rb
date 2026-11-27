module JobApplications
  # Daily (config/schedule.yml): re-seeds employers, reads every active
  # employer's public feed, keeps the Gulf postings, closes the ones that
  # disappeared, then matches. One failing feed never stops the run.
  class FetchPostingsJob < ApplicationJob
    queue_as :default

    CLOSED_RETENTION = 90.days
    AI_USAGE_RETENTION = 30.days

    def perform
      # Dark until SEERA_APPLY_ENABLED or SEERA_APPLY_TESTERS is set.
      return unless JobApplications.enabled_anywhere?

      result = EmployerSeeder.call
      result[:invalid].each { |line| Rails.logger.warn("[seera_apply] employers.yml skipped #{line}") }
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
            p.to_h.merge(employer_id: employer.id, city: GulfLocation.city_for(p.location), apply_email: ApplyEmail.from(p.description),
                         fetched_at: now, closed_at: nil)
          end
          Posting.upsert_all(rows, unique_by: %i[employer_id external_id],
                                   update_only: %i[title location country city url apply_url apply_email description posted_at fetched_at
                                                   closed_at])
        end
        employer.postings.open.where.not(external_id: postings.map(&:external_id)).update_all(closed_at: now, updated_at: now)
        employer.update!(last_fetched_at: now, last_error: nil)
      end
      Rails.logger.info("[seera_apply] #{employer.ats}/#{employer.identifier}: #{postings.size} Gulf postings")
    rescue StandardError => e
      Rails.logger.error("[seera_apply] fetch failed for #{employer.ats}/#{employer.identifier}: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, tags: { pack: "job_applications", ats: employer.ats })
      employer.update_columns(last_error: "#{e.class}: #{e.message}".first(1_000), updated_at: Time.current)
    end

    # Retention: closed postings (their matches cascade), old AI counters,
    # and the documents and answers of long-finished applications.
    def clean_up
      Application.purge_old!
      Posting.where(closed_at: ...CLOSED_RETENTION.ago).delete_all
      AiUsage.where(day: ...AI_USAGE_RETENTION.ago.to_date).delete_all
    end
  end
end
