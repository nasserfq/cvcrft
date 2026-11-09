# Refuses new AI work while the provider's breaker is open or the AI queue is
# full (AiCircuit.busy?). It runs as a before_action, so nothing has been
# charged yet. Same UX as UserRateLimit: 429 JSON or a redirect with an alert.
module AiCapacity
  extend ActiveSupport::Concern

  class_methods do
    # Declare after authenticate_user! and the record loaders, so a missing
    # record is still a 404. `queue` is the Sidekiq queue the action's job uses.
    def refuse_when_ai_busy(only:, queue: AiCircuit::DEFAULT_QUEUE, **options)
      before_action(only: only, **options) { render_ai_busy if AiCircuit.busy?(queue: queue) }
    end
  end

  private

  def render_ai_busy
    message = t("ux_i18n.ai_busy")
    response.set_header("Retry-After", AiCircuit::OPEN_FOR.to_i.to_s)
    if request.format.json? || request.xhr?
      render json: { error: message }, status: :too_many_requests
    else
      redirect_back fallback_location: root_path, alert: message
    end
  end
end
