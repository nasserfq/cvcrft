module JobApplications
  # A file kept with an application, in Postgres so it is deleted with the
  # account and included in backups: the tailored CV PDF and the proof of
  # sending (a confirmation-page screenshot or the sent email).
  class Document < ApplicationRecord
    KINDS = %w[cv_pdf proof].freeze
    MAX_BYTES = { "cv_pdf" => 2.megabytes, "proof" => 1.megabyte }.freeze

    belongs_to :application, class_name: "JobApplications::Application", inverse_of: :documents

    validates :kind, inclusion: { in: KINDS }
    validates :kind, uniqueness: { scope: :application_id }
    validates :content_type, :filename, :data, presence: true
    validate :within_size_cap

    before_validation { self.byte_size = data&.bytesize }

    # Writes (or replaces) the application's document of this kind.
    def self.store!(application, kind:, data:, content_type:, filename:)
      document = find_or_initialize_by(application:, kind:)
      document.update!(data: data.to_s.b, content_type:, filename:)
      document
    end

    private

    def within_size_cap
      cap = MAX_BYTES[kind]
      errors.add(:data, :too_long, count: cap) if cap && byte_size.to_i > cap
    end
  end
end
