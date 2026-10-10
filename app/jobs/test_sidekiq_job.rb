class TestSidekiqJob
  include Sidekiq::Job

  def perform(message)
    Rails.logger.info "Sidekiq is working! Message: #{message}"

    # Simulate some work
    sleep 2

    Rails.logger.info "Test job completed successfully!"
  end
end
