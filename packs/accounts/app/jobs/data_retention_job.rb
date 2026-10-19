# Enforces the PDPL retention periods (docs/pdpl.md), daily via
# config/schedule.yml:
#   - OTP codes: deleted after 1 day
#   - failed CV analyses, CV imports and LinkedIn imports: deleted after 30 days
#   - extracted CV text on analyses and imports: cleared after 30 days
#
# Generated PDFs (cv_generations) are the user's own documents and stay until
# the account is deleted, so this job never touches them.
#
# Every step works in batches and logs counts only, never record contents.
class DataRetentionJob < ApplicationJob
  queue_as :default

  OTP_RETENTION = 1.day
  CV_DATA_RETENTION = 30.days
  BATCH_SIZE = 1_000

  def perform
    otp_cutoff = OTP_RETENTION.ago
    cv_cutoff = CV_DATA_RETENTION.ago

    counts = { otp_verifications_deleted: delete_in_batches(OtpVerification.where(created_at: ...otp_cutoff)) }

    [ CvAnalysis, CvImport, LinkedinImport ].each do |model|
      old = model.where(created_at: ...cv_cutoff)
      key = model.model_name.plural

      counts[:"#{key}_failed_deleted"] = delete_in_batches(old.failed)
      counts[:"#{key}_text_cleared"] = clear_text_in_batches(old.where.not(extracted_text: nil))
    end

    Rails.logger.info "[DataRetentionJob] #{counts.map { |name, count| "#{name}=#{count}" }.join(' ')}"
    counts
  end

  private

  def delete_in_batches(scope)
    total = 0
    scope.in_batches(of: BATCH_SIZE) { |batch| total += batch.delete_all }
    total
  end

  def clear_text_in_batches(scope)
    total = 0
    scope.in_batches(of: BATCH_SIZE) { |batch| total += batch.update_all(extracted_text: nil, updated_at: Time.current) }
    total
  end
end
