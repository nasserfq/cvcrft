module CvGenerator
  # Writes a parsed generation result onto the CvGeneration: the AI's
  # professional summary, the tokens, the full structure (whose other
  # sections come from the saved resume's snapshot) and the PDF drawn from
  # it, all in one update. No resume is written.
  class ResultPersister
    # Notes left by earlier failed attempts or a regenerate in flight; a
    # successful write clears them.
    STALE_KEYS = %w[error error_backtrace pdf_error regenerating_at].freeze

    def initialize(cv_generation)
      @cv_generation = cv_generation
    end

    # The structure the PDF is drawn from: the AI's summary, every other
    # section from `snapshot` (the source resume's ResumeSnapshot hash).
    def self.generated_data(result, snapshot:)
      raise ArgumentError, "snapshot is required" unless snapshot

      {
        professional_summary: result[:professional_summary],
        work_experiences: snapshot[:work_experiences],
        skills: snapshot[:skills],
        educations: snapshot[:educations],
        certifications: snapshot[:certifications],
        languages: snapshot[:languages]
      }
    end

    # Stores the summary in the main field and the full structure plus
    # `pdf_metadata` (CvGenerator::PdfRenderer#call) in metadata. The status
    # is left as it is; a generation cancelled meanwhile is not written and
    # false is returned.
    def record!(result, snapshot:, pdf_metadata: {})
      generated_data = self.class.generated_data(result, snapshot: snapshot)

      @cv_generation.with_lock do
        next false if @cv_generation.cancelled?

        safe_meta = (@cv_generation.metadata || {}).except(*STALE_KEYS)
        @cv_generation.update!(
          generated_content: result[:professional_summary],
          tokens_used: result[:tokens_used],
          metadata: safe_meta.merge({
            generated_data: generated_data,
            ats_optimization_notes: result[:ats_optimization_notes],
            generation_notes: result[:generation_notes],
            raw_response: result[:raw_response]
          }.deep_stringify_keys).merge(pdf_metadata.deep_stringify_keys)
        )
      end
    end
  end
end
