module Coach
  # The chat's draft uses the flat shape ResumeBuilder::PublicApi.create_from_draft takes.
  module Draft
    class Invalid < StandardError; end

    HEADER = %w[complete_name email phone_number city country].freeze
    SECTIONS = (%w[header professional_summary] + ResumeBuilder::PublicApi::REQUIRED.keys).freeze
    ARRAY_FIELDS = %w[skill_names responsibilities].freeze

    module_function

    # Returns a new draft with section set to value; messages go back to the model, so say how to fix it.
    def merge(draft, section, value)
      case section
      when "header"
        raise Invalid, "header must be a JSON object with #{HEADER.join(', ')}" unless value.is_a?(Hash)

        draft.merge(value.slice(*HEADER))
      when "professional_summary"
        raise Invalid, "professional_summary must be a non-empty string" unless value.is_a?(String) && value.present?

        draft.merge(section => value)
      when *ResumeBuilder::PublicApi::REQUIRED.keys
        raise Invalid, "#{section} must be a JSON array of objects (the whole list)" unless value.is_a?(Array)

        draft.merge(section => value.each_with_index.map { |entry, i| entry(section, entry, i) })
      else
        raise Invalid, "unknown section #{section.inspect}; use one of #{SECTIONS.join(', ')}"
      end
    end

    def entry(section, entry, index)
      raise Invalid, "#{section}[#{index}] must be a JSON object" unless entry.is_a?(Hash)

      missing = ResumeBuilder::PublicApi::REQUIRED[section].reject { |key| entry[key].present? }
      raise Invalid, "#{section}[#{index}] is missing #{missing.join(', ')}; ask the user for it" if missing.any?

      ARRAY_FIELDS.each do |key|
        next if !entry.key?(key) || entry[key].is_a?(Array)

        raise Invalid, "#{section}[#{index}].#{key} must be an array of strings"
      end
      entry.slice(*ResumeBuilder::PublicApi::FIELDS[section])
    end
  end
end
