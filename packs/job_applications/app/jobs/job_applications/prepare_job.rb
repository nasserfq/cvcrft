module JobApplications
  # Builds an application's pack (tailored CV PDF and form answers, Unit 2's
  # PackBuilder), then routes it with finish_pack!. A manual row keeps its PDF
  # for the user and ends "unsupported". The row stays preparing between
  # attempts; once they run out it ends "prepare_failed".
  class PrepareJob < ApplicationJob
    queue_as :default

    retry_on StandardError, attempts: 3 do |job, error|
      job.give_up(error)
    end
    retry_on AiCircuit::OpenError, wait: ->(_executions) { AiCircuit.retry_delay(AiCircuit::OpenError.new) }, attempts: 5 do |job, error|
      job.give_up(error)
    end

    def perform(application_id)
      application = Application.find_by(id: application_id)
      return unless application&.status == "preparing"
      return unless JobApplications.enabled_for?(application.user)

      pack = build_pack(application)
      if application.channel == "manual"
        application.fallback!("unsupported")
      else
        application.finish_pack!(**pack.to_h.symbolize_keys.slice(:questions, :answers, :missing, :summary, :cover_letter))
      end
    end

    def give_up(error)
      Rails.logger.error("[seera_apply] pack failed for application #{arguments.first}: #{error.class}: #{error.message}")
      Sentry.capture_exception(error, tags: { pack: "job_applications" }) unless error.is_a?(AiCircuit::OpenError)
      Application.find_by(id: arguments.first)&.fallback!("prepare_failed")
    end

    private

    # {questions:, answers:, missing:, summary:, cover_letter:}; writes the cv_pdf document.
    def build_pack(application)
      PackBuilder.new(application).call
    end
  end
end
