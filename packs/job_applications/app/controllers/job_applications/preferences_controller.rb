module JobApplications
  class PreferencesController < BaseController
    MAX_TITLES = 10

    def update
      attrs = preference_params
      preference.assign_attributes(attrs)
      if params.dig(:preference, :consent) == "1"
        # Re-accepting keeps the first date unless the text changed since.
        unless preference.consent_accepted?
          preference.consent_accepted_at = Time.current
          preference.consent_version = CONSENT_VERSION
        end
      else
        preference.consent_accepted_at = nil
        preference.consent_version = nil
      end

      if preference.save
        redirect_to auto_apply_root_path, notice: t("auto_apply.flash.preferences_saved")
      else
        fields = preference.errors.attribute_names.uniq.map { |a| t("auto_apply.preferences.#{a}", default: a.to_s.humanize) }
        redirect_to auto_apply_root_path, alert: t("auto_apply.flash.preferences_invalid", fields: fields.to_sentence)
      end
    end

    private

    def preference_params
      p = params.fetch(:preference, {}).permit(:titles, :min_score, :daily_cap, :mode, :linkedin_url, :paused, countries: [])
      attrs = {}
      if p.key?(:titles)
        attrs[:titles] = p[:titles].to_s.split(/[,،\n]/).map(&:squish).compact_blank.uniq.first(MAX_TITLES)
      end
      attrs[:countries] = Array(p[:countries]).compact_blank.uniq if p.key?(:countries)
      attrs[:min_score] = p[:min_score].to_i if p.key?(:min_score)
      attrs[:daily_cap] = p[:daily_cap].to_i if p.key?(:daily_cap)
      attrs[:mode] = p[:mode].to_s if p.key?(:mode)
      attrs[:linkedin_url] = p[:linkedin_url].to_s.strip.presence if p.key?(:linkedin_url)
      attrs[:paused] = p[:paused] == "1" if p.key?(:paused)
      attrs
    end
  end
end
