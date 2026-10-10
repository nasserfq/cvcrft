# app/controllers/concerns/posthog_trackable.rb
# Include this concern in controllers to easily track user events
module PosthogTrackable
  extend ActiveSupport::Concern

  private

  # Analytics consent is opt-in. The banner in app/views/shared/_posthog.html.erb
  # writes this cookie; until the visitor accepts, nothing is sent — including
  # from the server, which would otherwise ship email, name and IP to PostHog.
  def analytics_consent?
    cookies[:analytics_consent] == "granted"
  end

  # Track an event for the current user
  def track_event(event_name, properties = {})
    return unless analytics_consent?
    return unless current_user

    POSTHOG.capture({
      distinct_id: current_user.id.to_s,
      event: event_name,
      properties: default_properties.merge(properties)
    })
  rescue => e
    Rails.logger.error("[PostHog] Failed to track #{event_name}: #{e.message}")
  end

  # Identify user with their properties (call on login/signup)
  def identify_user(user = current_user)
    return unless analytics_consent?
    return unless user

    POSTHOG.identify({
      distinct_id: user.id.to_s,
      properties: {
        email: user.email,
        name: user.name,
        created_at: user.created_at&.iso8601,
        resumes_count: user.resumes.count,
        translations_count: user.ai_translations.count
      }
    })
  rescue => e
    Rails.logger.error("[PostHog] Failed to identify user: #{e.message}")
  end

  # Default properties included with every event
  def default_properties
    {
      "$current_url" => request.original_url,
      "$referrer" => request.referrer,
      "user_agent" => request.user_agent,
      "ip" => request.remote_ip,
      "environment" => Rails.env
    }
  end
end
