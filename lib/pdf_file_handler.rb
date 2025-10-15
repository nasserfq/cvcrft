module PdfFileHandler
  # Helper method to generate a file-based PDF
  def self.generate_pdf_file(resume, content)
    require "prawn"
    require "prawn/table"
    require "fileutils"
    require "securerandom"

    # Generate a unique filename and path
    filename = resume.complete_name.present? ?
               "#{resume.complete_name.parameterize}_resume.pdf" :
               "resume_#{SecureRandom.hex(6)}.pdf"

    pdf_dir = Rails.root.join("tmp", "pdfs", "generated")
    FileUtils.mkdir_p(pdf_dir)
    pdf_path = pdf_dir.join(filename)

    Rails.logger.info "Generating PDF at: #{pdf_path}"

    # Create the PDF document using Prawn
    pdf = Prawn::Document.new(
      page_size: "A4",
      margin: [ 36, 36, 36, 36 ],
      page_layout: :portrait,
      info: {
        Title: "Resume - #{resume.complete_name}",
        Author: "CVCraft",
        Creator: "CVCraft Resume Generator",
        Producer: "Prawn via CVCraft",
        CreationDate: Time.now
      }
    )

    # Write the PDF directly to file
    pdf.render_file(pdf_path.to_s)

    # Verify the file was created properly
    if File.exist?(pdf_path)
      file_size = File.size(pdf_path)
      Rails.logger.info "PDF generated successfully at #{pdf_path} (#{file_size} bytes)"
      { path: pdf_path.to_s, filename: filename, size: file_size }
    else
      Rails.logger.error "Failed to create PDF at #{pdf_path}"
      nil
    end
  end

  # Helper method to send a PDF file in the controller
  def self.send_pdf_file(controller, file_path, filename)
    if File.exist?(file_path)
      controller.send_file(
        file_path,
        filename: filename || File.basename(file_path),
        type: "application/pdf",
        disposition: "attachment"
      )
      true
    else
      false
    end
  end
end
