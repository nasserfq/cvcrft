# Redraws the PDF of every completed AI generation from its stored
# generated data, on the same row (no AI call, no new rows). A generation
# whose PDF can't be drawn keeps the one it has. Used by the admin area after
# a template change.
class CvGenerationPdfRegenerator
  def self.call
    new.call
  end

  def call
    cv_generations = CvGeneration.ai_generated
                                 .where(status: "completed")
                                 .where("metadata->>'pdf_generated' = 'true'")

    total = cv_generations.count
    processed = success = failed = 0

    cv_generations.find_each do |cv_gen|
      processed += 1
      if redraw(cv_gen)
        success += 1
      else
        failed += 1
      end

      if processed % 5 == 0
        Rails.logger.info "PDF Regeneration: #{processed}/#{total} processed, #{success} successful, #{failed} failed"
      end
    rescue => e
      failed += 1
      Rails.logger.error "Failed to regenerate PDF for CV ##{cv_gen.id}: #{e.message}"
    end

    Rails.logger.info "PDF regeneration complete: #{success}/#{total} successful, #{failed} failed"

    { total: total, success: success, failed: failed }
  end

  private

  # Returns whether the new PDF was stored. Rows without generated data or a
  # saved resume have nothing to draw from.
  def redraw(cv_gen)
    generated_data = cv_gen.metadata&.dig("generated_data")
    resume = cv_gen.resume
    return false if generated_data.blank? || resume.nil? || resume.user_id != cv_gen.user_id

    pdf_metadata = CvGenerator::PdfRenderer.new(resume, cv_gen.metadata["ats_template"]).call(generated_data)

    cv_gen.with_lock do
      next false unless cv_gen.completed?

      cv_gen.update_columns(metadata: cv_gen.metadata.except("pdf_error").merge(pdf_metadata), updated_at: Time.current)
    end
  end
end
