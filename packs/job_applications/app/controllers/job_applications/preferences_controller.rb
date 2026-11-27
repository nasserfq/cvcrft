module JobApplications
  # Saves titles and cities, then scores the new set right away (unless the AI is busy).
  class PreferencesController < BaseController
    def update
      preference.assign_attributes(preference_params)
      changed = preference.titles_changed? || preference.cities_changed?

      if preference.save
        MatchJob.perform_later(current_user.id) if changed && !AiCircuit.busy?
        redirect_to my_jobs_root_path, notice: t("seera_apply.flash.saved")
      else
        fields = preference.errors.attribute_names.uniq.map { |attribute| field_label(attribute) }
        redirect_to my_jobs_root_path, alert: t("seera_apply.flash.invalid", fields: fields.to_sentence)
      end
    end

    private

    # The cities have no heading on the page, so their names stand in for one.
    def field_label(attribute)
      return t("seera_apply.cities").values.join(" · ") if attribute == :cities

      t("seera_apply.#{attribute}", default: attribute.to_s.humanize)
    end

    def preference_params
      p = params.fetch(:preference, {}).permit(:titles, cities: [])
      attrs = {}
      if p.key?(:titles)
        attrs[:titles] = p[:titles].to_s.split(/[,،\n]/).map(&:squish).compact_blank.uniq.first(Preference::MAX_TITLES)
      end
      attrs[:cities] = Array(p[:cities]).compact_blank.uniq if p.key?(:cities)
      attrs
    end
  end
end
