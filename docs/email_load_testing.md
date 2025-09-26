# Email Load Testing Guide

This guide explains how to perform load testing for email sending with 10,000+ users in your CV Craft application.

## Overview

The email load testing system allows you to:

- Test email sending capabilities with large volumes of users
- Monitor performance and identify bottlenecks
- Optimize your email infrastructure
- Ensure reliable email delivery under load

## Quick Start

### 1. Run Basic Load Test

```bash
# Test with 10,000 users (default)
bundle exec rails email:load_test

# Test with custom parameters
bundle exec rails email:load_test USERS=5000 BATCH_SIZE=50
```

### 2. Use the Admin Dashboard

1. Navigate to `/admin/email_load_test`
2. Configure your test parameters
3. Click "Start Load Test"
4. Monitor progress in real-time

### 3. Monitor Jobs

```bash
# Check job status
bundle exec rails email:monitor

# Or visit the Sidekiq dashboard
open http://localhost:3000/sidekiq
```

## Configuration

### Environment Variables

Set these environment variables to optimize performance:

```bash
# Sidekiq concurrency
export SIDEKIQ_CONCURRENCY=10

# Email processing
export EMAIL_CHUNK_SIZE=50
export EMAIL_CHUNK_DELAY=0.1

# Job concurrency
export JOB_CONCURRENCY=2
```

### AWS SES Limits

Before testing, ensure your AWS SES account can handle the load:

1. **Sending Quota**: Check your daily sending quota
2. **Sending Rate**: Default is 14 emails/second
3. **Request Rate**: Default is 20 requests/second

To increase limits:

1. Go to AWS SES Console
2. Navigate to "Sending Statistics"
3. Request a limit increase

## Test Scenarios

### Scenario 1: OTP Emails (10,000 users)

```bash
# Run the test
bundle exec rails email:load_test

# Expected results:
# - Duration: ~15-20 minutes
# - Success rate: >95%
# - Memory usage: <1GB
```

### Scenario 2: Welcome Emails (50,000 users)

```bash
# Use the admin dashboard with:
# - Total Users: 50000
# - Batch Size: 100
# - Email Type: Welcome
```

### Scenario 3: Mixed Email Types

```ruby
# In Rails console
EmailLoadTestJob.perform_later(10000, 100, 'otp')
EmailLoadTestJob.perform_later(10000, 100, 'welcome')
EmailLoadTestJob.perform_later(10000, 100, 'notification')
```

## Monitoring and Metrics

### Real-time Monitoring

1. **Sidekiq Dashboard**: `http://localhost:3000/sidekiq`
2. **Admin Dashboard**: `/admin/email_load_test`
3. **Rails Logs**: `tail -f log/development.log`

### Key Metrics to Watch

- **Queue Size**: Number of pending jobs
- **Processing Rate**: Jobs processed per minute
- **Error Rate**: Failed jobs percentage
- **Memory Usage**: Worker memory consumption
- **AWS SES Metrics**: Bounce rate, complaint rate

### Performance Benchmarks

| Users  | Batch Size | Duration  | Success Rate | Memory Usage |
| ------ | ---------- | --------- | ------------ | ------------ |
| 1,000  | 50         | 2-3 min   | >99%         | <200MB       |
| 10,000 | 100        | 15-20 min | >95%         | <500MB       |
| 50,000 | 100        | 60-90 min | >90%         | <1GB         |

## Troubleshooting

### Common Issues

#### 1. High Memory Usage

**Problem**: Workers consuming too much memory
**Solution**:

```bash
# Reduce batch size
export EMAIL_CHUNK_SIZE=25

# Increase worker count
export SIDEKIQ_CONCURRENCY=5
```

#### 2. AWS SES Rate Limiting

**Problem**: "Rate exceeded" errors
**Solution**:

```bash
# Increase delay between batches
export EMAIL_CHUNK_DELAY=0.5

# Reduce concurrent workers
export SIDEKIQ_CONCURRENCY=3
```

#### 3. Job Failures

**Problem**: High failure rate
**Solution**:

1. Check AWS credentials
2. Verify email addresses
3. Check network connectivity
4. Review error logs

### Debug Commands

```bash
# Check Sidekiq status
bundle exec rails runner "puts Sidekiq::Stats.new.inspect"

# Clear failed jobs
bundle exec rails runner "Sidekiq::DeadSet.new.clear"

# Check queue sizes
bundle exec rails runner "Sidekiq::Queue.all.each { |q| puts \"#{q.name}: #{q.size}\" }"

# Monitor memory usage
ps aux | grep sidekiq
```

## Optimization Tips

### 1. Database Optimization

```ruby
# Add indexes for better performance
add_index :users, :email
add_index :users, :created_at
```

### 2. Redis Optimization

```yaml
# config/redis.yml
production:
 url: redis://localhost:6379/0
 timeout: 5
 reconnect_attempts: 3
 pool_size: 20
```

### 3. Sidekiq Optimization

```yaml
# config/sidekiq.yml
:concurrency: 10
:queues:
 - [mailers, 2]
 - [default, 1]
:max_retries: 3
:timeout: 30
```

### 4. AWS SES Optimization

- Use connection pooling
- Implement exponential backoff
- Monitor bounce and complaint rates
- Use dedicated IP addresses for high volume

## Production Deployment

### 1. Infrastructure Requirements

- **Redis**: 2GB+ memory, persistent storage
- **Sidekiq Workers**: 2-4 workers minimum
- **Database**: Optimized for concurrent reads
- **Monitoring**: Application performance monitoring

### 2. Scaling Strategy

```bash
# Horizontal scaling
# Run multiple Sidekiq workers
bundle exec sidekiq -c 10 -q mailers,2 -q default,1
bundle exec sidekiq -c 10 -q mailers,2 -q default,1
```

### 3. Monitoring Setup

- Set up alerts for queue size
- Monitor memory usage
- Track AWS SES metrics
- Set up error rate alerts

## Cleanup

### After Testing

```bash
# Clean up test data
bundle exec rails email:cleanup

# Or use the admin dashboard
# Navigate to /admin/email_load_test
# Click "Clean Up Test Data"
```

### Manual Cleanup

```ruby
# In Rails console
User.where("email LIKE ?", "%test%").destroy_all
Sidekiq::Queue.new('mailers').clear
```

## Best Practices

1. **Start Small**: Begin with 1,000 users, then scale up
2. **Monitor Closely**: Watch metrics during testing
3. **Test Regularly**: Run load tests before major releases
4. **Document Results**: Keep records of performance metrics
5. **Plan for Scale**: Design for 10x current load
6. **Use Staging**: Test in staging environment first
7. **Backup Data**: Always backup before large tests

## Support

For issues or questions:

1. Check the logs: `tail -f log/development.log`
2. Review Sidekiq dashboard
3. Check AWS SES console
4. Contact the development team

## Additional Resources

- [Sidekiq Documentation](https://github.com/mperham/sidekiq)
- [AWS SES Documentation](https://docs.aws.amazon.com/ses/)
- [Rails Active Job Guide](https://guides.rubyonrails.org/active_job_basics.html)

