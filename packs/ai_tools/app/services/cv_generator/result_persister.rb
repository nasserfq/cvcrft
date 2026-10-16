module CvGenerator
  # Writes a parsed generation result onto the CvGeneration: the AI's
  # professional summary, the tokens, and the full structure, whose other
  # sections come from the saved resume's snapshot. No resume is written.
  class ResultPersister
    def initialize(cv_generation)
      @cv_generation = cv_generation
    end

    # Store only the professional summary in the main field, but the FULL
    # structure in metadata. `snapshot` is the source resume's ResumeSnapshot
    # hash; a saved resume is required.
    def record!(result, snapshot:)
      raise ArgumentError, "snapshot is required" unless snapshot

      # Use the saved resume's data for every section except the summary
      Rails.logger.info "Using existing resume data for skills, experience, etc."

      existing_data = snapshot
      Rails.logger.info "📊 Formatted skills: #{existing_data[:skills].inspect}"

      generated_data = {
        professional_summary: result[:professional_summary], # Only use AI-generated summary
        work_experiences: existing_data[:work_experiences],
        skills: existing_data[:skills],
        educations: existing_data[:educations],
        certifications: existing_data[:certifications],
        languages: existing_data[:languages]
      }

      Rails.logger.info "📦 Generated data skills to be stored: #{generated_data[:skills].inspect}"

      safe_meta = (@cv_generation.metadata || {})
      @cv_generation.update!(
        generated_content: result[:professional_summary],
        status: "processing",
        tokens_used: result[:tokens_used],
        metadata: safe_meta.merge({
          generated_data: generated_data,
          ats_optimization_notes: result[:ats_optimization_notes],
          generation_notes: result[:generation_notes],
          raw_response: result[:raw_response]
        })
      )
    end
  end
end
