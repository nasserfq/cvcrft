module JobApplications
  # Sends one queued application: claims it under the profile lock, logs the
  # disclosure, runs the submitter, then records the outcome. Charges only
  # after the row is sent and committed, so a failure never costs anything.
  # See docs/state-machines.md "Seera Apply applications".
  class Sender
    KIND = :job_application

    attr_reader :application

    def initialize(application)
      @application = application
    end

    def call
      return unless claim!

      disclosure = Disclosure.record!(application)
      submitter = Submitters.for(application)
      cv = application.cv_pdf
      return finish_fallback("unsupported", disclosure) unless submitter
      return finish_fallback("prepare_failed", disclosure) unless cv

      result = submitter.new(application, cv_pdf: cv.data).call
      result.sent? ? finish_sent(result, disclosure) : finish_fallback(result.error_code.presence || "send_error", disclosure)
    rescue Submitters::Retryable => e
      retry_or_fail(e, disclosure)
    rescue StandardError => e
      fail_after_error(e, disclosure)
    end

    # Records the charge for a sent row once. Returns the charge, or nil when
    # there was nothing to charge. :blocked after a confirmed send is not
    # undone: it is stored as "uncollected" and reported.
    def charge!
      outcome = nil
      application.with_lock do
        next unless application.status == "sent" && application.charge.nil?

        outcome = Billing::UsageGate.allow!(application.user, KIND, key: "job_application:#{application.id}")
        application.update_columns(charge: outcome == :blocked ? "uncollected" : outcome.to_s, updated_at: Time.current)
      end
      if outcome == :blocked
        Sentry.capture_message("[seera_apply] sent application #{application.id} could not be charged",
                               level: :warning, tags: { pack: "job_applications" })
      end
      outcome
    end

    private

    def user = application.user

    # queued -> sending, or sets a hold and leaves it queued. True when claimed.
    def claim!
      profile = Profile.find_by(user_id: application.user_id)
      return false unless profile

      profile.with_lock do
        application.reload
        if application.status != "queued"
          false
        elsif application.posting.closed_at
          application.fallback!("closed")
          false
        elsif (hold = hold_for(profile))
          application.update_columns(hold:, updated_at: Time.current) unless hold == :busy || application.hold == hold
          false
        else
          application.transition!(from: "queued", to: "sending", hold: nil, error_code: nil, claimed_at: Time.current,
                                                  submit_clicked_at: nil, attempts: application.attempts + 1)
        end
      end
    end

    # A hold name, :busy (another of the user's rows is sending; no label), or nil.
    def hold_for(profile)
      return "paused" unless profile.consented?
      return "paused" if !profile.sending? && application.approved_at.nil?
      return :busy if Application.where(user_id: application.user_id, status: "sending").exists?
      return "daily_cap" if sent_today >= DAILY_SEND_LIMIT
      return "no_credits" unless Billing::UsageGate.available?(user, KIND)

      nil
    end

    def sent_today
      day = Time.current.in_time_zone(TIME_ZONE).all_day
      Application.where(user_id: application.user_id, status: %w[sending sent], claimed_at: day).count
    end

    def finish_sent(result, disclosure)
      now = Time.current
      Application.transaction do
        moved = application.transition!(from: "sending", to: "sent", sent_at: now, confirmation: result.confirmation.to_h)
        raise ActiveRecord::Rollback unless moved

        store_proof(result)
      end
      disclosure&.mark!("sent")
      charge! if application.status == "sent"
    end

    def store_proof(result)
      return if result.proof_bytes.blank?

      type = result.proof_type.presence || "image/jpeg"
      extension = type == "message/rfc822" ? "eml" : "jpg"
      Document.transaction(requires_new: true) do
        Document.store!(application, kind: "proof", data: result.proof_bytes, content_type: type,
                                     filename: "application-#{application.id}-proof.#{extension}")
      end
    rescue StandardError => e
      # A proof that can't be stored (over the size cap) never undoes a confirmed send.
      Rails.logger.warn("[seera_apply] proof not stored for application #{application.id}: #{e.message}")
    end

    def finish_fallback(code, disclosure)
      application.fallback!(code)
      disclosure&.mark!("fallback")
      nil
    end

    # Before the click: queued again for DispatchJob, or failed once attempts are used up.
    def retry_or_fail(error, disclosure)
      application.reload
      return fail_after_error(error, disclosure) if application.submit_clicked_at

      Rails.logger.warn("[seera_apply] application #{application.id} will retry: #{error.message}")
      if application.attempts >= Application::MAX_ATTEMPTS
        application.fallback!("timeout")
        disclosure&.mark!("fallback")
      else
        application.transition!(from: "sending", to: "queued", claimed_at: nil)
        disclosure&.mark!("retry")
      end
      nil
    end

    # Any other error. After the click it may have reached the employer, so
    # it is "unconfirmed" and never retried; before it, "send_error".
    def fail_after_error(error, disclosure)
      Rails.logger.error("[seera_apply] send failed for application #{application.id}: #{error.class}: #{error.message}")
      Sentry.capture_exception(error, tags: { pack: "job_applications" })
      application.reload
      application.fallback!(application.submit_clicked_at ? "unconfirmed" : "send_error") if application.status == "sending"
      disclosure&.mark!("error")
      nil
    end
  end
end
