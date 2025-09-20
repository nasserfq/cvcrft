#!/usr/bin/env ruby

# Test script for CV generation functionality
require_relative 'config/environment'

puts "Testing CV Generation Implementation..."
puts "=" * 50

# Check if we have a user
user = User.first
if user.nil?
  puts "Creating a test user..."
  user = User.create!(
    name: "Test User",
    email: "test@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  puts "✓ Test user created with ID: #{user.id}"
else
  puts "✓ Using existing user with ID: #{user.id}"
end

# Test job description
job_description = <<~DESC
  We are looking for a Senior Software Engineer to join our team. 
  The ideal candidate should have:
  - 5+ years of experience in Ruby on Rails development
  - Strong knowledge of JavaScript, React, and modern frontend frameworks
  - Experience with cloud platforms (AWS, Azure)
  - Database design and optimization skills
  - Agile development methodologies
  - Leadership experience and mentoring abilities
  - Excellent communication skills
  - Bachelor's degree in Computer Science or related field
DESC

puts "\nTesting CV Generation Service..."
puts "-" * 30

# Initialize the service
service = AzureOpenaiService.new(user.id)

# Test CV generation
puts "Queuing CV generation job..."
result = service.generate_cv(job_description, {
  complete_name: "John Doe",
  email: "john.doe@example.com",
  temperature: 0.7,
  max_tokens: 15000
})

puts "✓ CV generation job queued successfully!"
puts "Response: #{result}"

# Check if the job was created
cv_generation = CvGeneration.where(user_id: user.id).last
if cv_generation
  puts "✓ CV generation record created with ID: #{cv_generation.id}"
  puts "Status: #{cv_generation.status}"
  puts "Job Description: #{cv_generation.job_description[0..100]}..."
else
  puts "✗ No CV generation record found"
end

puts "\nTesting with existing resume..."
puts "-" * 30

# Check if we have a resume
resume = Resume.first
if resume.nil?
  puts "Creating a test resume..."
  resume = Resume.create!(
    complete_name: "Jane Smith",
    email: "jane.smith@example.com",
    professional_summary: "Experienced software developer with expertise in web technologies",
    summary: "Experienced software developer with expertise in web technologies"
  )
  puts "✓ Test resume created with ID: #{resume.id}"
else
  puts "✓ Using existing resume with ID: #{resume.id}"
end

# Test CV generation with existing resume
service_with_resume = AzureOpenaiService.new(user.id, resume.id)
result2 = service_with_resume.generate_cv(job_description, {
  temperature: 0.7,
  max_tokens: 15000
})

puts "✓ CV generation with existing resume queued successfully!"
puts "Response: #{result2}"

# Check the second job
cv_generation2 = CvGeneration.where(user_id: user.id).last
if cv_generation2
  puts "✓ Second CV generation record created with ID: #{cv_generation2.id}"
  puts "Status: #{cv_generation2.status}"
  puts "Resume ID: #{cv_generation2.resume_id}"
else
  puts "✗ No second CV generation record found"
end

puts "\nTesting statistics..."
puts "-" * 30

stats = service.get_cv_generation_stats
puts "✓ Statistics retrieved:"
puts "  Total generations: #{stats[:total_generations]}"
puts "  Completed: #{stats[:completed]}"
puts "  Failed: #{stats[:failed]}"
puts "  Processing: #{stats[:processing]}"
puts "  Total tokens used: #{stats[:total_tokens_used]}"

puts "\n" + "=" * 50
puts "Test completed! Check the Sidekiq web interface at /sidekiq to see job processing."
puts "You can also visit /cv_generations to see the CV generation interface."
