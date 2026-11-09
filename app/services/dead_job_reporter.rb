# Sidekiq death handler (config/initializers/sidekiq.rb): a job that ran out of
# retries, or was killed at once, becomes one Sentry error naming the job
# class, queue and error class. Never the args or the error message: either
# can carry user data.
module DeadJobReporter
  def self.call(job, exception)
    job_class = job["wrapped"].presence || job["class"].to_s
    queue = job["queue"].to_s
    error_class = exception&.class&.name || job["error_class"].to_s

    Sentry.with_scope do |scope|
      # Drop whatever the job's own scope carried (its args, user, breadcrumbs).
      scope&.clear
      Sentry.capture_message(
        "Sidekiq job died: #{job_class}",
        level: :error,
        tags: { job_class: job_class, queue: queue, error_class: error_class },
        fingerprint: [ "sidekiq-dead-job", job_class, error_class ]
      )
    end
  rescue StandardError => e
    Rails.logger.error("[DeadJobReporter] #{e.class}")
  end
end
