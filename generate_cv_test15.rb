  #!/usr/bin/env ruby
  # [Previous code remains the same until the certificates section]

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    y_position = pdf.cursor

    # Draw the certificate name in bold first
    pdf.text cert[:name], style: :bold, size: 10

    # Move back up to add the rest on the same line
    pdf.move_up 11.5

    # Calculate where the bold text ends
    name_width = pdf.width_of(cert[:name], style: :bold, size: 10)

    # Add status and organization info in regular text
    info_parts = []
    info_parts << "(#{cert[:status]})" if cert[:status]
    info_parts << "(#{cert[:organization]})" if cert[:organization]

    if info_parts.any?
      # Add a space after the certificate name and join the parts
      pdf.draw_text " #{info_parts.join(' ')}",
        at: [ name_width, pdf.cursor ],
        size: 10
    end

    # Add date on the right
    pdf.draw_text cert[:date],
      at: [ 500 - pdf.width_of(cert[:date], size: 10), pdf.cursor ],
      size: 10

    # Move down for the next item
    pdf.move_down 15
  end

# [Rest of the code remains the same]
