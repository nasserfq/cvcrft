#!/usr/bin/env ruby
# [Previous code remains the same until the section title generator]

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

  # [Previous code remains the same until certificates section]

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

# [Rest of the code remains the same]
