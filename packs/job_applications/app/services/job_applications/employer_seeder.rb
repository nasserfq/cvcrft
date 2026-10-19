module JobApplications
  # Loads config/employers.yml into auto_apply_employers. Employers dropped from
  # the file are deactivated, never deleted, so their postings and applications stay.
  class EmployerSeeder
    DEFAULT_PATH = Rails.root.join("packs/job_applications/config/employers.yml")
    ATTRIBUTES = %w[name host site country verified].freeze

    def self.call(path = DEFAULT_PATH) = new(path).call

    def initialize(path)
      @path = Pathname(path)
    end

    # => {created:, updated:, deactivated:, invalid: [...]}
    def call
      result = { created: 0, updated: 0, deactivated: 0, invalid: [] }
      unless @path.exist?
        result[:invalid] << "#{@path} not found"
        return result
      end

      seen = []
      entries.each_with_index do |entry, i|
        error = invalid_reason(entry)
        next result[:invalid] << "entry #{i + 1} (#{entry.is_a?(Hash) ? entry['name'] : entry.inspect}): #{error}" if error

        ats = entry["ats"].to_s.strip.downcase
        identifier = entry["identifier"].to_s.strip
        employer = Employer.find_or_initialize_by(ats:, identifier:)
        employer.assign_attributes(entry.slice(*ATTRIBUTES).transform_values { |v| v.is_a?(String) ? v.strip.presence : v })
        employer.country = employer.country&.upcase
        employer.verified = ActiveModel::Type::Boolean.new.cast(entry["verified"]) || false
        employer.active = entry.key?("active") ? ActiveModel::Type::Boolean.new.cast(entry["active"]) != false : true

        new_record = employer.new_record?
        changed = employer.changed?
        employer.save!
        result[:created] += 1 if new_record
        result[:updated] += 1 if changed && !new_record
        seen << employer.id
      end

      result[:deactivated] = Employer.where(active: true).where.not(id: seen).update_all(active: false, updated_at: Time.current)
      result
    end

    private

    # Either a bare list or {"employers" => [...]}.
    def entries
      data = YAML.safe_load_file(@path, permitted_classes: [ Date, Time ]) || []
      data = data["employers"] if data.is_a?(Hash)
      Array(data)
    end

    def invalid_reason(entry)
      return "not a mapping" unless entry.is_a?(Hash)
      return "name is required" if entry["name"].blank?
      return "identifier is required" if entry["identifier"].blank?

      ats = entry["ats"].to_s.strip.downcase
      return "unknown ats #{entry['ats'].inspect}" unless Fetchers::REGISTRY.key?(ats)
      return "workday needs host and site" if ats == "workday" && (entry["host"].blank? || entry["site"].blank?)

      nil
    end
  end
end
