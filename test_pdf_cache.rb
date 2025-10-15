#!/usr/bin/env ruby
require_relative 'app/jobs/cv_generator_job'
require 'logger'
require 'ostruct'
require 'json'
require 'digest'

# This test script verifies the PDF caching and version control
# Use this to test that version changes properly trigger PDF regeneration

puts "=== PDF Cache Test ==="
puts "Current PDF_VERSION: #{CvGeneratorJob::PDF_VERSION}"

# Mock classes similar to test_cv_job2.rb
String.class_eval do
  def truncate(length)
    return self unless size > length
    "#{self[0, length]}..."
  end

  def parameterize
    gsub(/[^a-zA-Z0-9\-_]/, '-').gsub(/-+/, '-').downcase
  end
end

Object.class_eval do
  def present?; !blank?; end
  def blank?; respond_to?(:empty?) ? empty? : !self; end
  def deep_symbolize_keys; self; end
end

module Rails
  def self.logger; @logger ||= Logger.new(STDOUT); end
  def self.application; OpenStruct.new(credentials: OpenStruct.new(azure: { openai_api_key: "FAKE" })); end
end

class Resume < OpenStruct
  def work_experiences; self[:work_experiences] || []; end
  def skills; self[:skills] || []; end
  def educations; self[:educations] || []; end
  def certifications; self[:certifications] || []; end
  def languages; self[:languages] || []; end
  def reload; self; end
end

class CvGeneration < OpenStruct
  def metadata; self[:metadata] ||= {}; end
  def update!(attributes); self.marshal_load(self.marshal_dump.merge(attributes)); end
  def reload; self; end
end

class User < OpenStruct; end

class TestCacheChecker < CvGeneratorJob
  def initialize(version_override = nil)
    @version_override = version_override
  end
  
  # Override PDF_VERSION constant if needed
  def pdf_version
    @version_override || PDF_VERSION
  end
  
  # Test version check
  def test_version_check
    # Create test data
    @cv_generation = CvGeneration.new(
      id: 1, 
      status: "completed",
      metadata: {
        "pdf_generated" => true,
        "pdf_data" => "fake_data",
        "pdf_version" => "1.0", # Old version
        "pdf_generated_at" => Time.now.to_i - 3600,
        "pdf_cache_key" => "test_key"
      }
    )
    @options = {}
    
    # Run check
    should_regen = pdf_regeneration_needed?
    puts "Version check test: Should regenerate? #{should_regen}"
    puts "  Stored version: #{@cv_generation.metadata['pdf_version']}"
    puts "  Current version: #{PDF_VERSION}"
    
    # Create version that matches
    @cv_generation.metadata["pdf_version"] = PDF_VERSION
    should_regen = pdf_regeneration_needed?
    puts "Version match test: Should regenerate? #{should_regen}"
  end
  
  # Test force regeneration
  def test_force_regeneration
    @cv_generation = CvGeneration.new(
      id: 1, 
      status: "completed",
      metadata: {
        "pdf_generated" => true,
        "pdf_data" => "fake_data",
        "pdf_version" => PDF_VERSION,
        "pdf_generated_at" => Time.now.to_i - 3600,
        "pdf_cache_key" => "test_key"
      }
    )
    
    # Without force flag
    @options = {}
    should_regen = pdf_regeneration_needed?
    puts "Without force flag: Should regenerate? #{should_regen}"
    
    # With force flag
    @options = { force_pdf_regeneration: true }
    should_regen = pdf_regeneration_needed?
    puts "With force flag: Should regenerate? #{should_regen}"
  end
  
  # Test status check
  def test_status_check
    @options = {}
    
    # Test with "processing" status
    @cv_generation = CvGeneration.new(
      id: 1, 
      status: "processing", # First-time generation
      metadata: {
        "pdf_generated" => true,
        "pdf_data" => "fake_data",
        "pdf_version" => PDF_VERSION,
        "pdf_generated_at" => Time.now.to_i - 3600,
        "pdf_cache_key" => "test_key"
      }
    )
    
    puts "Status test (processing): #{@cv_generation.status}"
    first_generation = @cv_generation.status == "processing"
    puts "Is first generation: #{first_generation}"
    
    # Test with "completed" status
    @cv_generation = CvGeneration.new(
      id: 1, 
      status: "completed", # Already done
      metadata: {
        "pdf_generated" => true,
        "pdf_data" => "fake_data",
        "pdf_version" => PDF_VERSION,
        "pdf_generated_at" => Time.now.to_i - 3600,
        "pdf_cache_key" => "test_key"
      }
    )
    
    puts "Status test (completed): #{@cv_generation.status}"
    first_generation = @cv_generation.status == "processing"
    puts "Is first generation: #{first_generation}"
  end
  
  # Test all checks
  def run_all_tests
    puts "\n=== Running Version Check Test ==="
    test_version_check
    
    puts "\n=== Running Force Regeneration Test ==="
    test_force_regeneration
    
    puts "\n=== Running Status Check Test ==="
    test_status_check
    
    puts "\n=== Tests Complete ==="
  end
end

# Run tests
test = TestCacheChecker.new
test.run_all_tests