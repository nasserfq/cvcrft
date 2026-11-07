# Fails AI work left pending or processing for too long (a killed worker or a
# lost job) and refunds its credit, every 10 minutes via config/schedule.yml.
# Each model's fail_stale! skips rows that finished meanwhile.
class StaleWorkSweeperJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 30.minutes
  MODEL_NAMES = %w[CvGeneration CvAnalysis AiTranslation CvImport LinkedinImport].freeze

  def perform
    cutoff = STALE_AFTER.ago

    counts = MODEL_NAMES.filter_map do |name|
      model = name.safe_constantize
      next unless model.respond_to?(:fail_stale!)

      [ model.model_name.plural, model.fail_stale!(older_than: cutoff) ]
    end.to_h

    Rails.logger.info "[StaleWorkSweeperJob] #{counts.map { |name, count| "#{name}_failed=#{count}" }.join(' ')}"
    counts
  end
end
