#!/usr/bin/env ruby
# Test script for Amazon SES
# Run with: bundle exec rails runner test_ses.rb

begin
  # Test Amazon SES connection
  client = Aws::SES::Client.new(
    region: Rails.application.credentials.aws[:region] || 'us-east-1',
    access_key_id: Rails.application.credentials.aws[:access_key_id],
    secret_access_key: Rails.application.credentials.aws[:secret_access_key]
  )

  # Test sending a simple email
  response = client.send_email({
    source: Rails.application.credentials.aws[:from_email],
    destination: {
      to_addresses: [ Rails.application.credentials.aws[:from_email] ] # Send to yourself for testing
    },
    message: {
      subject: {
        data: "CV Craft - Test Email",
        charset: 'UTF-8'
      },
      body: {
        text: {
          data: "This is a test email from CV Craft. If you receive this, your SES setup is working!",
          charset: 'UTF-8'
        }
      }
    }
  })

  puts "✅ SUCCESS: Email sent successfully!"
  puts "Message ID: #{response.message_id}"
  puts "Your Amazon SES setup is working correctly!"

rescue Aws::SES::Errors::ServiceError => e
  puts "❌ AWS SES Error: #{e.message}"
  puts "Please check your credentials and email verification status."
rescue => e
  puts "❌ Error: #{e.message}"
  puts "Please check your configuration."
end
