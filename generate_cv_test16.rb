#!/usr/bin/env ruby
require 'prawn'
require 'date'
require 'ostruct'

# [Previous data and helper methods remain the same...]

def generate_test_pdf(resume, data)
  pdf = Prawn::Document.new(
    page_size: "A4",
    margin: [ 40, 40, 40, 40 ],
    page_layout: :portrait
  )

  # [Previous sections remain the same until certificates...]

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    # Store current vertical position
    y_position = pdf.cursor

    # Draw the certificate name in bold
    pdf.font("Helvetica", style: :bold) do
      pdf.draw_text cert[:name], at: [ 0, y_position ], size: 10
    end

    # Calculate where the bold text ends
    name_width = pdf.width_of(cert[:name], style: :bold, size: 10)

    # Add status and organization info in regular text
    info_parts = []
    info_parts << "(#{cert[:status]})" if cert[:status]
    info_parts << "(#{cert[:organization]})" if cert[:organization]

    if info_parts.any?
      pdf.font("Helvetica", style: :normal) do
        pdf.draw_text " #{info_parts.join(' ')}",
          at: [ name_width, y_position ],
          size: 10
      end
    end

    # Add date on the right
    pdf.font("Helvetica", style: :normal) do
      pdf.draw_text cert[:date],
        at: [ 500 - pdf.width_of(cert[:date], size: 10), y_position ],
        size: 10
    end

    # Move down for the next item
    pdf.move_down 15
  end

  # [Rest of the code remains the same...]
  pdf.render
end

# Generate and save the test PDF
begin
  puts "Generating CV PDF..."
  pdf_content = generate_test_pdf(resume, test_data)
  output_path = File.join(Dir.pwd, "test16.pdf")
  File.write(output_path, pdf_content)
  puts "✓ Successfully generated CV PDF!"
  puts "PDF saved at: #{output_path}"
rescue => e
  puts "Error generating CV:"
  puts e.message
  puts e.backtrace
end
