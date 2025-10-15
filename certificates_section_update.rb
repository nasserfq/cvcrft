#!/usr/bin/env ruby
require 'prawn'
require 'date'
require 'ostruct'

  # [Previous code remains the same until the certificates section]

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    y_position = pdf.cursor

    # Bold text line (certificate name)
    pdf.text cert[:name], style: :bold, size: 10

    # Move up to add organization/status on the same line
    pdf.move_up 11.5

    # Calculate spacing
    name_width = pdf.width_of(cert[:name], style: :bold, size: 10)

    # Add status and organization info
    info_text = []
    info_text << "(#{cert[:status]})" if cert[:status]
    info_text << "(#{cert[:organization]})" if cert[:organization]

    # Position details text after the bold name
    if info_text.any?
      pdf.draw_text info_text.join(" "),
        at: [ name_width + 5, pdf.cursor ],
        size: 10
    end

    # Add date with right alignment
    pdf.text_box cert[:date],
      size: 10,
      at: [ 400, y_position ],
      width: 100,
      align: :right

    pdf.move_down 5
  end

# [Rest of the code remains the same]
