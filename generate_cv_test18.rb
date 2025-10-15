#!/usr/bin/env ruby
require 'prawn'
require 'date'
require 'ostruct'

# [Previous test_data and resume_data remain the same...]

def generate_section_title(pdf, title)
  pdf.move_down 10
  pdf.fill_color "000080" # Navy blue color
  pdf.text title, size: 13, style: :bold
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.fill_color "000000" # Reset to black
  pdf.stroke_color "000080" # Keep blue line
  pdf.move_down 12  # Increased from 8 to 12 for better spacing
end

def generate_test_pdf(resume, data)
  pdf = Prawn::Document.new(
    page_size: "A4",
    margin: [ 40, 40, 40, 40 ],
    page_layout: :portrait
  )

  pdf.font "Helvetica"

  # Name at the top
  pdf.text resume.complete_name.to_s.strip, size: 20, style: :bold, align: :center
  pdf.move_down 4

  # Contact info on one line
  contact_text = "#{resume.email} | #{resume.phone_number} | #{resume.city}, #{resume.country}"
  pdf.text contact_text, size: 10, align: :center

  # Blue line under contact info
  pdf.stroke_color "000080"
  pdf.stroke_horizontal_rule
  pdf.move_down 15

  # Professional Summary
  generate_section_title(pdf, "Professional Summary")
  pdf.text data[:professional_summary].to_s.strip, size: 10, align: :justify
  pdf.move_down 10

  # Education
  generate_section_title(pdf, "Education")
  data[:educations].each do |education|
    # Keep degree titles bold
    pdf.text education[:degree].to_s.strip, size: 11, style: :bold
    pdf.move_up 13
    pdf.text "#{education[:start_date]} - #{education[:end_date]}", align: :right, size: 10
    pdf.text education[:institution], size: 10
    pdf.text education[:gpa].to_s, size: 10 if education[:gpa]
    pdf.move_down 5
  end

  # Work Experience
  generate_section_title(pdf, "Work Experience")
  data[:work_experiences].each do |exp|
    # Keep job titles bold
    pdf.text exp[:job_title], size: 11, style: :bold
    pdf.move_up 13
    pdf.text "#{exp[:start_date]} - #{exp[:end_date].to_s.capitalize}", align: :right, size: 10
    pdf.text exp[:company], size: 10

    Array(exp[:responsibilities]).each do |resp|
      pdf.text "• #{resp}", size: 10, leading: 2
    end
    pdf.move_down 8
  end

  # Skills
  generate_section_title(pdf, "Skills")
  data[:skills].each do |skill|
    # Category in bold with colon
    pdf.text "#{skill[:category]}:", size: 10, style: :bold
    # Skills in regular text
    pdf.text skill[:details], size: 10
    pdf.move_down 2
  end

  # Certificates
  generate_section_title(pdf, "Certificates")
  pdf.move_down 5  # Add extra space after the section title
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

    # Move down for next item
    pdf.move_down 15
  end

  # Languages
  generate_section_title(pdf, "Languages")
  data[:languages].each do |lang|
    # Make language name bold
    pdf.text lang[:language], size: 10, style: :bold
    pdf.move_up 12
    pdf.text lang[:proficiency], align: :right, size: 10
    pdf.move_down 2
  end

  pdf.render
end

# Generate and save the test PDF
begin
  puts "Generating CV PDF..."
  resume_data = OpenStruct.new(
    complete_name: "Nasser Alqahtani",
    email: "non1993@protonmail.com",
    phone_number: "+966505570007",
    city: "Riyadh",
    country: "Saudi Arabia"
  )

  pdf_content = generate_test_pdf(resume_data, test_data)
  output_path = File.join(Dir.pwd, "test18.pdf")
  File.write(output_path, pdf_content)
  puts "✓ Successfully generated CV PDF!"
  puts "PDF saved at: #{output_path}"
rescue => e
  puts "Error generating CV:"
  puts e.message
  puts e.backtrace
end
