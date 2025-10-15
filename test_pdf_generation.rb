#!/usr/bin/env ruby

# Simple test for PDF generation
require 'prawn'
require 'fileutils'

puts "Testing basic PDF generation..."

begin
  # Create a simple PDF
  pdf = Prawn::Document.new
  pdf.text "Test PDF Generation"
  pdf.text "This is a test to see if PDF generation works."

  # Save to file
  FileUtils.mkdir_p("tmp/test")
  pdf.render_file("tmp/test/test.pdf")

  # Check the file
  if File.exist?("tmp/test/test.pdf")
    size = File.size("tmp/test/test.pdf")
    header = IO.binread("tmp/test/test.pdf", 10)
    puts "✓ PDF generated successfully: #{size} bytes"
    puts "✓ Header: #{header.inspect}"
    puts "✓ Valid PDF: #{header.start_with?('%PDF')}"
  else
    puts "✗ PDF file not created"
  end

rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.join("\n")
end
