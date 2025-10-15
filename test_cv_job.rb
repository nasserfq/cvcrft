#!/usr/bin/env ruby
require 'rails'
require_relative 'app/jobs/cv_generator_job'

# Mock the Rails logger for testing
class Rails
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.application
    OpenStruct.new(
      credentials: OpenStruct.new(
        azure: { openai_api_key: ENV['AZURE_OPENAI_API_KEY'] }
      )
    )
  end
end

# Test data
job_description = "Seeking an experienced Project Manager with a strong technical background in AI and software development. The ideal candidate should have experience with Ruby on Rails, AI integration, and agile project management methodologies."

# Create test user and resume
class User < OpenStruct
  def cv_generations
    @cv_generations ||= []
  end
end

class Resume < OpenStruct
  def self.create!(attrs)
    new(attrs)
  end

  def update!(attrs)
    attrs.each { |k, v| self[k] = v }
    self
  end

  def reload
    self
  end
end

class CvGeneration < OpenStruct
  def self.create!(attrs)
    new(attrs.merge(metadata: {}))
  end

  def update!(attrs)
    attrs.each { |k, v| self[k] = v }
    self
  end
end

# Create test data
user = User.new(id: 1)
cv_generation = CvGeneration.create!(
  user_id: user.id,
  job_description: job_description,
  status: "processing"
)
user.cv_generations << cv_generation

# Test options
options = {
  complete_name: "Nasser Alqahtani",
  email: "non1993@protonmail.com",
  phone_number: "+966505570007",
  city: "Riyadh",
  country: "Saudi Arabia"
}

begin
  puts "Starting CV generation test..."
  job = CvGeneratorJob.new
  job.perform(job_description, user.id, nil, options)
  puts "CV generation completed successfully!"

  # Get the generated PDF data
  pdf_data = Base64.decode64(cv_generation.metadata["pdf_data"])
  output_path = File.join(Dir.pwd, "test_cv_job.pdf")

  # Save the PDF
  File.write(output_path, pdf_data)
  puts "✓ PDF saved at: #{output_path}"
rescue => e
  puts "Error during CV generation:"
  puts e.message
  puts e.backtrace
end
