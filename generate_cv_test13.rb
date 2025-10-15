  #!/usr/bin/env ruby
  # Previous code remains the same until certificates section...

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    # Create the full line with proper formatting
    y_position = pdf.cursor

    # Certificate name in bold
    pdf.formatted_text_box [
      { text: cert[:name], size: 10, style: :bold }
    ], at: [ 0, y_position ]

    # Status and organization in regular text
    org_text = []
    org_text << "(#{cert[:status]})" if cert[:status]
    org_text << "(#{cert[:organization]})" if cert[:organization]

    if !org_text.empty?
      pdf.text_box org_text.join(' '),
        size: 10,
        at: [ pdf.width_of(cert[:name], size: 10) + 5, y_position ]
    end

    # Date on the right
    pdf.text_box cert[:date],
      size: 10,
      at: [ 400, y_position ],
      width: 100,
      align: :right

    # Move down for next item
    pdf.move_down 15
  end

# Rest of the code remains the same...
