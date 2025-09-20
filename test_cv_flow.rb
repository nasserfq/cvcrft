#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

# Test CV Generation Flow
puts "Testing CV Generation Flow..."
puts "=" * 50

# Test the service directly
user_id = User.first&.id || 1
service = AzureOpenaiService.new(user_id)

job_description = "We are looking for a Senior Software Engineer to join our team. The ideal candidate should have:
- 5+ years of experience in software development
- Strong knowledge of React, Node.js, and PostgreSQL
- Experience with cloud platforms (AWS, Azure, or GCP)
- Excellent communication skills
- Bachelor's degree in Computer Science or related field"

puts "✓ Using existing user with ID: #{user_id}"
puts "✓ Job Description: #{job_description.truncate(100)}..."

# Generate CV
puts "\nGenerating CV..."
result = service.generate_cv(job_description, {
  complete_name: "John Doe",
  email: "john.doe@example.com",
  temperature: 0.7,
  max_tokens: 15000
})

puts "✓ CV generation result: #{result.inspect}"

if result[:cv_generation_id]
  cv_generation = CvGeneration.find(result[:cv_generation_id])
  puts "✓ CV Generation ID: #{cv_generation.id}"
  puts "✓ Status: #{cv_generation.status}"
  puts "✓ Created at: #{cv_generation.created_at}"
  
  puts "\n" + "=" * 50
  puts "🎯 SUCCESS! Now you can:"
  puts "1. Visit: http://127.0.0.1:3000/cv_generations/#{cv_generation.id}"
  puts "2. The page will auto-refresh every 3 seconds while processing"
  puts "3. When complete, you'll see the PDF rendered with React"
  puts "4. You can download the PDF directly from the page"
  puts "=" * 50
else
  puts "❌ Failed to get CV generation ID"
end
