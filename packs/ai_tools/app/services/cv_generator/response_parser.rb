module CvGenerator
  # Turns the model's reply into the symbol-keyed result hash the job stores.
  # With a `snapshot` (the source resume's ResumeSnapshot hash) only the new
  # professional summary is taken from the reply; every section comes from the
  # snapshot.
  class ResponseParser
    def initialize(snapshot:)
      @snapshot = snapshot
    end

    def call(response)
      content = response.content
      tokens_used = AiModel.token_count(response)

      # Models differ on whether they fence their JSON. gpt-4.1-mini returned it
      # bare; Claude wraps it in ```json. Without this the parse raises and the
      # rescue below dumps the whole raw response into professional_summary.
      # The other four jobs already strip the fence.
      if (fenced = content.match(/```(?:json)?\s*(.*?)\s*```/m))
        content = fenced[1]
      end

      begin
        parsed_content = JSON.parse(content)

        if @snapshot
          # When we have an existing resume, preserve ALL existing data
          existing_data = @snapshot
          result = {
            # Take only the new professional summary
            professional_summary: parsed_content["professional_summary"],
            # Explicitly preserve all existing data
            work_experiences: existing_data[:work_experiences] || [],
            skills: existing_data[:skills] || [],
            educations: existing_data[:educations] || [],
            certifications: existing_data[:certifications] || [],
            languages: existing_data[:languages] || [],
            # Include the optimization notes
            ats_optimization_notes: "Preserved all existing resume data",
            generation_notes: "Updated only professional summary while preserving all existing data",
            tokens_used: tokens_used,
            raw_response: content,
            using_existing_data: true
          }
        else
          # For new resumes, use all generated content
          result = {
            professional_summary: parsed_content["professional_summary"],
            work_experiences: parsed_content["work_experiences"] || [],
            skills: parsed_content["skills"] || [],
            educations: parsed_content["educations"] || [],
            certifications: parsed_content["certifications"] || [],
            languages: parsed_content["languages"] || [],
            ats_optimization_notes: parsed_content["ats_optimization_notes"],
            generation_notes: parsed_content["generation_notes"],
            tokens_used: tokens_used,
            raw_response: content
          }
        end
        result
      rescue JSON::ParserError
        # Fallback: if not JSON, use the raw content as the summary
        {
          professional_summary: content,
          work_experiences: [], skills: [], educations: [], certifications: [], languages: [],
          ats_optimization_notes: "Response was not in expected JSON format",
          generation_notes: "Response was not in expected JSON format",
          tokens_used: tokens_used,
          raw_response: content
        }
      end
    end
  end
end
