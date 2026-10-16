# Re-runs CvGeneratorJob synchronously for every completed CV generation that
# has a PDF, forcing the PDF to be rebuilt. Used by the admin area.
class CvGenerationPdfRegenerator
  def self.call
    new.call
  end

  def call
    # Get all completed CV generations with metadata
    cv_generations = CvGeneration.where(status: "completed")
                                .where("metadata->>'pdf_generated' = 'true'")

    # Count of PDFs to process
    total = cv_generations.count
    processed = 0
    success = 0
    failed = 0

    cv_generations.find_each do |cv_gen|
      begin
        processed += 1

        # Skip if no data available
        unless cv_gen.job_description.present? && cv_gen.user_id.present?
          failed += 1
          next
        end

        # Get basic info
        job_description = cv_gen.job_description
        user_id = cv_gen.user_id
        resume_id = cv_gen.resume_id

        # Run the job with force regeneration
        job = CvGeneratorJob.new
        job.perform(
          job_description,
          user_id,
          resume_id,
          { force_pdf_regeneration: true }
        )

        success += 1

        # Log progress every 5 items
        if processed % 5 == 0
          Rails.logger.info "PDF Regeneration: #{processed}/#{total} processed, #{success} successful, #{failed} failed"
        end

      rescue => e
        failed += 1
        Rails.logger.error "Failed to regenerate PDF for CV ##{cv_gen.id}: #{e.message}"
      end
    end

    # Final stats
    Rails.logger.info "PDF regeneration complete: #{success}/#{total} successful, #{failed} failed"

    { total: total, success: success, failed: failed }
  end
end
