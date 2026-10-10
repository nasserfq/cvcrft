class Admin::EmailLoadTestController < ApplicationController
  # HTTP Basic Authentication for admin access. See Admin::ApplicationController
  # for why there is no fallback password.
  http_basic_authenticate_with(
    name: ENV.fetch("ADMIN_USERNAME", "admin"),
    password: ENV.fetch("ADMIN_PASSWORD") { SecureRandom.hex(32) }
  )

  # Use custom layout instead of Administrate layout
  layout "admin_email_load_test"

  def index
    @stats = get_email_stats
    @recent_tests = get_recent_tests
    @queue_stats = get_queue_stats
  end

  def start_test
    total_users = params[:total_users]&.to_i || 10_000
    batch_size = params[:batch_size]&.to_i || 100
    email_type = params[:email_type] || "otp"
    simultaneous = params[:simultaneous] == "true"

    # Validate parameters
    if total_users > 50_000
      flash[:alert] = "Maximum 50,000 users allowed for load testing"
      redirect_to admin_email_load_test_index_path and return
    end

    # Start the appropriate load test
    if simultaneous
      job_id = start_simultaneous_load_test_job(total_users, email_type)
      flash[:notice] = "SIMULTANEOUS load test started! Job ID: #{job_id}. All #{total_users} emails will be sent at once. Monitor progress below."
    else
      job_id = start_load_test_job(total_users, batch_size, email_type)
      flash[:notice] = "Batch load test started! Job ID: #{job_id}. Monitor progress below."
    end

    redirect_to admin_email_load_test_index_path
  end

  def stop_test
    begin
      # Clear all pending jobs in the mailers queue
      Sidekiq::Queue.new("mailers").clear
      flash[:notice] = "Load test stopped. All pending email jobs have been cleared."
    rescue => e
      Rails.logger.error "Error stopping load test: #{e.message}"
      flash[:alert] = "Error stopping load test: #{e.message}"
    end

    redirect_to admin_email_load_test_index_path
  end

  def monitor
    @queue_stats = get_queue_stats
    @recent_jobs = get_recent_jobs

    respond_to do |format|
      format.html
      format.json { render json: @queue_stats }
    end
  end

  def results
    @job_id = params[:job_id]
    @results = get_job_results(@job_id) if @job_id

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end

  def cleanup
    # Clean up test data
    test_users = User.where("email LIKE ?", "%test%")
    count = test_users.count

    if count > 0
      test_users.destroy_all
      flash[:notice] = "Cleaned up #{count} test users"
    else
      flash[:alert] = "No test users found to clean up"
    end

    redirect_to admin_email_load_test_index_path
  end

  private

  def get_email_stats
    {
      total_users: User.count,
      test_users: User.where("email LIKE ?", "%test%").count,
      total_emails_sent: get_total_emails_sent,
      emails_today: get_emails_sent_today
    }
  end

  def get_recent_tests
    # Get recent batch email job results from cache
    recent_tests = []

    # This would need to be implemented based on how you store test results
    # For now, we'll return a placeholder
    recent_tests
  end

  def get_queue_stats
    begin
      stats = Sidekiq::Stats.new

      {
        processed: stats.processed,
        failed: stats.failed,
        enqueued: stats.enqueued,
        retry: stats.retry_size,
        dead: stats.dead_size,
        queues: Sidekiq::Queue.all.map { |q| { name: q.name, size: q.size } }
      }
    rescue => e
      Rails.logger.error "Error getting queue stats: #{e.message}"
      {
        processed: 0,
        failed: 0,
        enqueued: 0,
        retry: 0,
        dead: 0,
        queues: []
      }
    end
  end

  def start_load_test_job(total_users, batch_size, email_type)
    # Create a job to run the load test
    job = EmailLoadTestJob.perform_later(total_users, batch_size, email_type)
    job.job_id
  end

  def start_simultaneous_load_test_job(total_users, email_type)
    # Create a job to run the simultaneous load test
    job = SimultaneousEmailLoadTestJob.perform_later(total_users, email_type)
    job.job_id
  end

  def get_job_results(job_id)
    # Get results from cache
    Rails.cache.read("batch_email_results_#{job_id}")
  end

  def get_total_emails_sent
    # This would need to be tracked in your database
    # For now, return a placeholder
    0
  end

  def get_emails_sent_today
    # This would need to be tracked in your database
    # For now, return a placeholder
    0
  end

  def get_recent_jobs
    begin
      # Get recent jobs from Sidekiq
      recent_jobs = []

      # Get jobs from different queues
      Sidekiq::Queue.all.each do |queue|
        queue.each do |job|
          recent_jobs << {
            queue: queue.name,
            class: job.klass,
            args: job.args,
            created_at: Time.at(job.created_at),
            enqueued_at: Time.at(job.enqueued_at)
          }
        end
      end

      # Sort by creation time, most recent first
      recent_jobs.sort_by { |job| -job[:created_at].to_i }.first(10)
    rescue => e
      Rails.logger.error "Error getting recent jobs: #{e.message}"
      []
    end
  end
end
