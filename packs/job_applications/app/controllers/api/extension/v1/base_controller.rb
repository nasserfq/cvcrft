module Api
  module Extension
    module V1
      # The browser extension's API. Token auth through X-Seera-Token only: no
      # session, cookie, CSRF or Devise. The calls come from the extension's
      # service worker, whose host_permissions include this origin, so Chrome
      # sends them without CORS and no CORS middleware is needed. Content
      # scripts never call it; they message the worker.
      class BaseController < ActionController::API
        # Rate-limit counters. The test env's cache is a null store, so tests
        # point RATE_STORE.backend at a MemoryStore.
        class RateStore
          attr_accessor :backend

          def increment(...) = (backend || Rails.cache).increment(...)
        end
        RATE_STORE = RateStore.new

        before_action :authenticate_token!
        rate_limit to: 120, within: 1.minute, by: :rate_key, with: :rate_limited, store: RATE_STORE, name: "extension"
        around_action :use_user_locale

        private

        attr_reader :token

        def authenticate_token!
          @token = JobApplications::Token.authenticate(request.headers["X-Seera-Token"])
          return error(:unauthorized, :unauthorized) unless token
          return error(:forbidden, :disabled) unless JobApplications.enabled_for?(token.user)

          token.update_column(:last_used_at, Time.current) if token.last_used_at.nil? || token.last_used_at < 1.minute.ago
        end

        def current_user = token.user

        def preference
          @preference ||= JobApplications::Preference.find_by(user: current_user)
        end

        def require_consent!
          error(:forbidden, :consent_required) unless preference&.consent_accepted?
        end

        def latest_resume
          @latest_resume ||= ResumeBuilder::PublicApi.latest_complete(current_user)
        end

        # The digest, never the raw token, goes into the cache key.
        def rate_key = JobApplications::Token.digest(request.headers["X-Seera-Token"]).first(32)

        def rate_limited = error(:too_many_requests, :rate_limited)

        def use_user_locale(&)
          locale = current_user.locale.to_s
          locale = "ar" unless I18n.available_locales.map(&:to_s).include?(locale)
          I18n.with_locale(locale, &)
        end

        # Every error is {"error": code, "message": localised text}.
        def error(status, code, message = nil)
          locale = token&.user&.locale.to_s.presence_in(I18n.available_locales.map(&:to_s)) || I18n.locale
          text = message || I18n.t("auto_apply.api.errors.#{code}", locale:)
          render json: { error: code.to_s, message: text }, status:
        end
      end
    end
  end
end
