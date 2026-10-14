module Coach
  # The chat's draft uses the flat shape ResumeBuilder::PublicApi.create_from_draft takes.
  module Draft
    class Invalid < StandardError; end

    HEADER = %w[complete_name email phone_number city country].freeze
    SECTIONS = (%w[header professional_summary] + ResumeBuilder::PublicApi::REQUIRED.keys).freeze
    ARRAY_FIELDS = %w[skill_names responsibilities].freeze
    # What a proposal may rewrite: section => the field inside each entry (nil when the section is the text).
    REWRITABLE = { "professional_summary" => nil, "work_experience" => "responsibilities" }.freeze

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

    # Keeps whatever passes merge and drops the rest, since extracted or older resume data can be partial.
    def clean(raw)
      raw = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
      SECTIONS.reduce({}) do |draft, section|
        value = section == "header" ? raw.slice(*HEADER).compact_blank : raw[section]
        value = value.select { |item| valid_entry?(section, item) } if value.is_a?(Array)
        value.blank? ? draft : merge(draft, section, value)
      rescue Invalid
        draft
      end
    end

    # The value a rewrite would replace; raises Invalid when the target doesn't exist.
    def rewritable(draft, section, index)
      raise Invalid, "only #{REWRITABLE.keys.join(' and ')} can be rewritten" unless REWRITABLE.key?(section)
      return draft[section] unless (field = REWRITABLE[section])

      entries = Array(draft[section])
      unless index.is_a?(Integer) && index.between?(0, entries.size - 1)
        raise Invalid, "#{section} has #{entries.size} entries, so index #{index.inspect} does not exist"
      end
      entries[index][field]
    end

    # Returns the draft with the rewrite applied, re-validated by merge.
    def rewrite(draft, section, index, value)
      rewritable(draft, section, index)
      return merge(draft, section, value) unless (field = REWRITABLE[section])

      entries = draft[section].map(&:dup)
      entries[index] = entries[index].merge(field => value)
      merge(draft, section, entries)
    end

    # Structured-output schema for Coach::Extract, in the same flat shape as the draft.
    def json_schema
      field = lambda do |key|
        if ARRAY_FIELDS.include?(key) then { type: "array", items: { type: "string" } }
        elsif key == "is_current" then { type: "boolean" }
        else { type: "string" }
        end
      end
      object = ->(keys, required) { { type: "object", properties: keys.index_with(&field), required:, additionalProperties: false } }
      root = object.call(HEADER + %w[professional_summary], [])
      ResumeBuilder::PublicApi::REQUIRED.each do |section, required|
        root[:properties][section] = { type: "array", items: object.call(ResumeBuilder::PublicApi::FIELDS[section], required) }
      end
      { name: "cv", schema: root }
    end

    def valid_entry?(section, item)
      entry(section, item, 0)
      true
    rescue Invalid
      false
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
