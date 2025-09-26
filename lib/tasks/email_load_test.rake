namespace :email do
  desc "Load test email sending for 10,000 users"
  task load_test: :environment do
    puts "🚀 Starting email load test for 10,000 users..."

    # Configuration
    total_users = 10_000
    batch_size = 100
    delay_between_batches = 1 # seconds

    # Create test users if they don't exist
    create_test_users(total_users) unless User.count >= total_users

    # Start load test
    start_time = Time.current
    successful_sends = 0
    failed_sends = 0

    puts "📊 Test Configuration:"
    puts "   Total users: #{total_users}"
    puts "   Batch size: #{batch_size}"
    puts "   Delay between batches: #{delay_between_batches}s"
    puts "   Estimated duration: #{(total_users / batch_size * delay_between_batches / 60).round(2)} minutes"
    puts ""

    # Process in batches
    User.limit(total_users).find_in_batches(batch_size: batch_size).with_index do |batch, batch_index|
      batch_start_time = Time.current

      puts "📦 Processing batch #{batch_index + 1}/#{(total_users / batch_size).ceil} (#{batch.size} users)"

      # Enqueue jobs for this batch
      batch.each do |user|
        begin
          # Generate a test OTP for each user
          otp_code = generate_otp_code

          # Enqueue the email job
          SendOtpEmailJob.perform_later(user.email, otp_code)
          successful_sends += 1
        rescue => e
          puts "❌ Failed to enqueue job for user #{user.id}: #{e.message}"
          failed_sends += 1
        end
      end

      batch_duration = Time.current - batch_start_time
      puts "   ✅ Batch completed in #{batch_duration.round(2)}s"

      # Show progress
      progress = ((batch_index + 1) * batch_size.to_f / total_users * 100).round(2)
      puts "   📈 Progress: #{progress}% (#{successful_sends + failed_sends}/#{total_users})"

      # Delay between batches to avoid overwhelming the system
      sleep(delay_between_batches) unless batch_index == (total_users / batch_size).ceil - 1
    end

    total_duration = Time.current - start_time

    puts ""
    puts "🎉 Load test completed!"
    puts "📊 Results:"
    puts "   Total duration: #{format_duration(total_duration)}"
    puts "   Successful enqueues: #{successful_sends}"
    puts "   Failed enqueues: #{failed_sends}"
    puts "   Success rate: #{(successful_sends.to_f / total_users * 100).round(2)}%"
    puts "   Average time per user: #{(total_duration / total_users).round(4)}s"
    puts ""
    puts "💡 Check Sidekiq dashboard to monitor job processing:"
    puts "   - Jobs enqueued: #{successful_sends}"
    puts "   - Monitor at: http://localhost:3000/sidekiq (if running locally)"
  end

  desc "Monitor email job processing"
  task monitor: :environment do
    require "sidekiq/api"

    puts "📊 Email Job Monitoring Dashboard"
    puts "=" * 50

    # Get queue statistics
    stats = Sidekiq::Stats.new
    puts "📈 Queue Statistics:"
    puts "   Processed: #{stats.processed}"
    puts "   Failed: #{stats.failed}"
    puts "   Enqueued: #{stats.enqueued}"
    puts "   Retry: #{stats.retry_size}"
    puts "   Dead: #{stats.dead_size}"
    puts ""

    # Get queue details
    puts "📋 Queue Details:"
    Sidekiq::Queue.all.each do |queue|
      puts "   #{queue.name}: #{queue.size} jobs"
    end
    puts ""

    # Get worker information
    workers = Sidekiq::Workers.new
    puts "👷 Active Workers: #{workers.size}"
    workers.each do |process_id, thread_id, work|
      puts "   Process #{process_id}: #{work['payload']['class']} (#{work['queue']})"
    end
    puts ""

    # Get recent failures
    failures = Sidekiq::DeadSet.new
    if failures.size > 0
      puts "❌ Recent Failures (#{failures.size}):"
      failures.take(5).each do |job|
        puts "   #{job['class']}: #{job['error_message']}"
      end
    end
  end

  desc "SIMULTANEOUS load test - send all emails at once"
  task simultaneous_load_test: :environment do
    puts "🚀 Starting SIMULTANEOUS email load test for 10,000 users..."

    # Configuration
    total_users = ENV.fetch("USERS", 10_000).to_i
    email_type = ENV.fetch("EMAIL_TYPE", "otp")

    puts "📊 Test Configuration:"
    puts "   Total users: #{total_users}"
    puts "   Email type: #{email_type}"
    puts "   Mode: SIMULTANEOUS (all emails sent at once)"
    puts ""

    # Start the simultaneous load test
    start_time = Time.current
    job = SimultaneousEmailLoadTestJob.perform_later(total_users, email_type)

    puts "✅ SIMULTANEOUS load test job enqueued!"
    puts "   Job ID: #{job.job_id}"
    puts "   All #{total_users} emails will be sent simultaneously"
    puts ""
    puts "💡 Monitor progress:"
    puts "   - Admin dashboard: http://localhost:3000/admin/email_load_test"
    puts "   - Sidekiq dashboard: http://localhost:3000/sidekiq"
    puts "   - Monitor jobs: bundle exec rails email:monitor"
  end

  desc "Clean up test data"
  task cleanup: :environment do
    puts "🧹 Cleaning up test data..."

    # Delete test users (those with test emails)
    test_users = User.where("email LIKE ?", "%test%")
    count = test_users.count

    if count > 0
      test_users.destroy_all
      puts "✅ Deleted #{count} test users"
    else
      puts "ℹ️  No test users found"
    end

    # Clear failed jobs (optional)
    if ENV["CLEAR_FAILED_JOBS"] == "true"
      Sidekiq::DeadSet.new.clear
      puts "✅ Cleared failed jobs"
    end
  end

  private

  def create_test_users(count)
    puts "👥 Creating #{count} test users..."

    count.times do |i|
      User.create!(
        email: "test_user_#{i + 1}@example.com",
        created_at: Time.current,
        updated_at: Time.current
      )

      # Show progress every 1000 users
      if (i + 1) % 1000 == 0
        puts "   Created #{i + 1} users..."
      end
    end

    puts "✅ Created #{count} test users"
  end

  def generate_otp_code
    # Generate a 6-digit OTP code
    rand(100000..999999).to_s
  end

  def format_duration(seconds)
    if seconds < 60
      "#{seconds.round(2)}s"
    elsif seconds < 3600
      "#{(seconds / 60).round(2)}m"
    else
      hours = (seconds / 3600).floor
      minutes = ((seconds % 3600) / 60).floor
      "#{hours}h #{minutes}m"
    end
  end
end
