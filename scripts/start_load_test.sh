#!/bin/bash

# Email Load Testing Startup Script
# This script helps you quickly start email load testing

echo "🚀 CV Craft Email Load Testing Setup"
echo "====================================="

# Check if we're in the right directory
if [ ! -f "Gemfile" ]; then
    echo "❌ Error: Please run this script from the Rails project root directory"
    exit 1
fi

# Check if Redis is running
echo "🔍 Checking Redis connection..."
if ! redis-cli ping > /dev/null 2>&1; then
    echo "❌ Redis is not running. Please start Redis first:"
    echo "   brew services start redis  # macOS"
    echo "   sudo systemctl start redis # Linux"
    exit 1
fi
echo "✅ Redis is running"

# Check if Sidekiq is running
echo "🔍 Checking Sidekiq..."
if ! pgrep -f sidekiq > /dev/null; then
    echo "⚠️  Sidekiq is not running. Starting Sidekiq..."
    bundle exec sidekiq -d -c 10 -q mailers,2 -q default,1
    sleep 3
fi
echo "✅ Sidekiq is running"

# Check AWS credentials
echo "🔍 Checking AWS SES credentials..."
if ! bundle exec rails runner "AmazonSesService.new" > /dev/null 2>&1; then
    echo "❌ AWS SES credentials not configured. Please:"
    echo "   1. Set up your AWS credentials in config/credentials.yml.enc"
    echo "   2. Or set environment variables:"
    echo "      export AWS_ACCESS_KEY_ID=your_key"
    echo "      export AWS_SECRET_ACCESS_KEY=your_secret"
    echo "      export AWS_REGION=us-east-1"
    exit 1
fi
echo "✅ AWS SES credentials configured"

# Set environment variables for optimal performance
export SIDEKIQ_CONCURRENCY=10
export EMAIL_CHUNK_SIZE=50
export EMAIL_CHUNK_DELAY=0.1
export JOB_CONCURRENCY=2

echo ""
echo "🎯 Load Testing Options:"
echo "1. Quick test (1,000 users)"
echo "2. Standard test (10,000 users)"
echo "3. Large test (50,000 users)"
echo "4. Custom test"
echo "5. SIMULTANEOUS test (10,000 users at once)"
echo "6. Use admin dashboard"
echo "7. Monitor current jobs"
echo ""

read -p "Choose an option (1-7): " choice

case $choice in
    1)
        echo "🚀 Starting quick test with 1,000 users..."
        bundle exec rails email:load_test USERS=1000 BATCH_SIZE=50
        ;;
    2)
        echo "🚀 Starting standard test with 10,000 users..."
        bundle exec rails email:load_test USERS=10000 BATCH_SIZE=100
        ;;
    3)
        echo "🚀 Starting large test with 50,000 users..."
        bundle exec rails email:load_test USERS=50000 BATCH_SIZE=100
        ;;
    4)
        read -p "Enter number of users: " users
        read -p "Enter batch size (default 100): " batch_size
        batch_size=${batch_size:-100}
        echo "🚀 Starting custom test with $users users..."
        bundle exec rails email:load_test USERS=$users BATCH_SIZE=$batch_size
        ;;
    5)
        echo "🚀 Starting SIMULTANEOUS test with 10,000 users..."
        echo "⚠️  WARNING: This will send all 10,000 emails at once!"
        read -p "Are you sure? (y/N): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            bundle exec rails email:simultaneous_load_test USERS=10000
        else
            echo "❌ Cancelled"
        fi
        ;;
    6)
        echo "🌐 Opening admin dashboard..."
        echo "Navigate to: http://localhost:3000/admin/email_load_test"
        echo "Starting Rails server..."
        bundle exec rails server
        ;;
    7)
        echo "📊 Current job status:"
        bundle exec rails email:monitor
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "✅ Load testing setup complete!"
echo ""
echo "📊 Useful commands:"
echo "   Monitor jobs: bundle exec rails email:monitor"
echo "   Clean up: bundle exec rails email:cleanup"
echo "   Sidekiq dashboard: http://localhost:3000/sidekiq"
echo "   Admin dashboard: http://localhost:3000/admin/email_load_test"
echo ""
echo "📚 For more information, see: docs/email_load_testing.md"
