  #!/usr/bin/env ruby
  # Previous code remains the same until the certificates section...

  # Certificates
  generate_section_title(pdf, "Certificates")
  data[:certifications].each do |cert|
    # Use formatted_text to mix bold and regular styles
    pdf.formatted_text [
      { text: cert[:name], size: 10, style: :bold }  # Certificate name in bold
    ]

    # Add status and organization in regular text if they exist
    status_and_org = ""
    status_and_org += " (#{cert[:status]})" if cert[:status]
    status_and_org += " (#{cert[:organization]})" if cert[:organization]

    if !status_and_org.empty?
      pdf.move_up 11.5  # Adjust position to append to the same line
      pdf.text status_and_org, size: 10
    end

    # Add date on the right
    pdf.move_up 11.5
    pdf.text cert[:date], align: :right, size: 10
    pdf.move_down 2
  end

# Rest of the code remains the same...
