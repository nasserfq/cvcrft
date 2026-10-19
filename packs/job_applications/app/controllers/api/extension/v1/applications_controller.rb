module Api
  module Extension
    module V1
      # The apply loop: take the next approved application, answer its form, report the result.
      class ApplicationsController < BaseController
        DETAIL_KEYS = %w[filled unanswered dry_run final_url captcha login_wall questions].freeze
        MAX_DETAILS_BYTES = 20_000
        MAX_STORED_QUESTIONS = 100

        rate_limit to: 20, within: 1.minute, by: :rate_key, with: :rate_limited, store: RATE_STORE, name: "extension-next", only: :next
        rate_limit to: 30, within: 1.minute, by: :rate_key, with: :rate_limited, store: RATE_STORE, name: "extension-answers", only: :answers
        before_action :require_consent!, only: %i[next answers]
        before_action :set_application, only: %i[answers update]

        def next
          return head(:no_content) if preference.paused

          today = JobApplications.today(current_user, preference)
          return error(:too_many_requests, :daily_cap_reached) if today["remaining"].zero?

          application = JobApplications::Application.transaction do
            JobApplications::Application.requeue_stale!(current_user)
            JobApplications::Application.next_for(current_user)&.tap do |app|
              app.update!(status: "in_progress", started_at: Time.current)
            end
          end
          return head(:no_content) unless application

          # Outside the lock: an AI failure leaves cover_letter null and never errors.
          JobApplications::CoverLetter.for(application)
          render json: { application: application_json(application.reload) }
        end

        def answers
          return error(:conflict, :invalid_transition) unless @application.status == "in_progress"
          return error(:too_many_requests, :ai_limit_reached) if JobApplications::AiUsage.remaining(current_user, :answers, JobApplications::DAILY_ANSWER_LIMIT).zero?

          questions = request.request_parameters["questions"]
          answerer = JobApplications::Answerer.new(@application)
          answers = answerer.call(questions)
          store_questions(answerer.validate(questions), answers)
          render json: { answers: }
        rescue JobApplications::Answerer::Invalid => e
          error(:unprocessable_entity, :invalid, e.message)
        end

        def update
          body = request.request_parameters
          status = body["status"].to_s
          return error(:unprocessable_entity, :invalid, I18n.t("auto_apply.api.errors.bad_status")) unless JobApplications::Application::STATUSES.include?(status)
          return error(:conflict, :invalid_transition) unless @application.can_transition_to?(status)

          details = body["details"].is_a?(Hash) ? body["details"].slice(*DETAIL_KEYS) : {}
          merged = @application.details.merge(details)
          return error(:unprocessable_entity, :invalid, I18n.t("auto_apply.api.errors.details_too_large")) if merged.to_json.bytesize > MAX_DETAILS_BYTES

          now = Time.current
          @application.update!(
            status:, details: merged, error: body["error"].presence&.to_s&.first(500),
            finished_at: now, submitted_at: status == "submitted" ? now : @application.submitted_at
          )
          render json: { application: application_json(@application), today: JobApplications.today(current_user, preference).slice("submitted", "remaining") }
        end

        private

        def set_application
          @application = JobApplications::Application.where(user: current_user).find_by(id: params[:id])
          error(:not_found, :not_found) unless @application
        end

        def store_questions(questions, answers)
          values = answers.to_h { |a| [ a["id"], a["value"] ] }
          rows = questions.map { |q| q.slice("id", "label", "type", "options").merge("value" => values[q["id"]]) }
          stored = (Array(@application.details["questions"]) + rows).last(MAX_STORED_QUESTIONS)
          stored.shift while stored.any? && @application.details.merge("questions" => stored).to_json.bytesize > MAX_DETAILS_BYTES
          @application.update!(details: @application.details.merge("questions" => stored))
        end

        def application_json(app)
          posting = app.posting
          {
            id: app.id, status: app.status, score: app.score, score_reason: app.score_reason,
            apply_url: posting.apply_url, ats: posting.employer.ats, cover_letter: app.cover_letter,
            posting: {
              title: posting.title, company: posting.employer.name, location: posting.location,
              country: posting.country, url: posting.url, posted_at: posting.posted_at&.utc&.iso8601
            }
          }
        end
      end
    end
  end
end
