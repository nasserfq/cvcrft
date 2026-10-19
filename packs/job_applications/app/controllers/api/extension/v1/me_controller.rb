module Api
  module Extension
    module V1
      class MeController < BaseController
        def show
          pref = preference || JobApplications::Preference.new(user: current_user)
          render json: {
            user: { name: current_user.name, email: current_user.email, locale: current_user.locale },
            preferences: {
              titles: pref.titles, countries: pref.countries, min_score: pref.min_score, daily_cap: pref.daily_cap,
              mode: pref.mode, consent: pref.consent_accepted?, paused: pref.paused
            },
            today: JobApplications.today(current_user, preference),
            has_resume: latest_resume.present?
          }
        end
      end
    end
  end
end
