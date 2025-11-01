require "prawn"
require "prawn/table"
require "fileutils"
require "securerandom"

class AtsPdfGenerator
  def self.generate_pdf(resume, data)
    Rails.logger.info "=== ATS PDF GENERATOR STARTED ==="
    Rails.logger.info "Resume: #{resume.inspect}"

    filename = resume.complete_name.present? ? "#{resume.complete_name.parameterize}_resume.pdf" : "resume_#{SecureRandom.hex(6)}.pdf"
    pdf_path = Rails.root.join("tmp", "pdfs", "generated", filename)
    FileUtils.mkdir_p(File.dirname(pdf_path))

    # Set strict encoding to prevent issues with special characters
    Prawn::Document.generate(pdf_path, force_encoding: true) do |pdf|
      # Use core PDF font with encoding set
      pdf.font "Helvetica", enable_smart_quotes: false do
        # Header Section
        pdf.text resume.complete_name.to_s.strip, size: 20, style: :bold, align: :center
        pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: 10, align: :center
        pdf.move_down 20

        # Professional Summary
        pdf.text "PROFESSIONAL SUMMARY", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 10
        # Use the AI-generated summary first (from data), then fallback to stored resume
        summary = data[:professional_summary].to_s.strip.presence ||
                 resume.professional_summary_english.presence ||
                 resume.professional_summary.presence ||
                 "No professional summary available"
        pdf.text summary, size: 10
        pdf.move_down 20

        # Education Section
        pdf.text "EDUCATION", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 10
        Array(data[:educations]).each do |education|
          # Draw degree and date on the same line
          degree = education[:degree].to_s.strip
          date_text = "#{education[:start_date]} - #{education[:end_date]}"

          pdf.float do
            pdf.text date_text, size: 10, align: :right
          end
          pdf.text degree, size: 11, style: :bold

          # Institution on next line
          pdf.text education[:institution].to_s.strip, size: 10
          pdf.move_down 5
        end

        # Work Experience Section - Only show if there are work experiences
        if resume.work_experiences.present? && resume.work_experiences.any?
          pdf.text "WORK EXPERIENCE", size: 13, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 10

          # Sort experiences by start_date in reverse chronological order
          sorted_experiences = Array(resume.work_experiences).sort_by do |exp|
          begin
            # Handle current position
            if exp.is_current
              Time.current.to_i
            else
              # Parse date in YYYY-MM format
              date_str = exp.start_date.to_s
              if date_str =~ /^\d{4}-\d{2}$/
                Date.strptime(date_str, "%Y-%m").to_time.to_i
              else
                # Default to oldest date if invalid format
                Date.new(1900, 1, 1).to_time.to_i
              end
            end
          rescue
            # Default to oldest date if parsing fails
            Date.new(1900, 1, 1).to_time.to_i
          end
        end.reverse  # Reverse to get descending order

        sorted_experiences.each do |experience|
          # Display date in top right corner
          date_text = "#{experience.start_date} - #{experience.is_current ? 'Present' : experience.end_date}"
          pdf.float do
            pdf.text date_text, size: 10, align: :right
          end

          # Display job title in bold with proper spacing - preserve original case
          pdf.text experience.job_title.to_s.strip, size: 11, style: :bold
          pdf.move_down 2  # Reduced space between title and company
          # Display company name under job title - preserve original case
          pdf.text experience.company.to_s.strip, size: 10
          pdf.move_down 4  # Space between company and responsibilities

          # Get responsibilities from the work experience
          raw_responsibilities = experience.responsibilities.presence || []

          # Ensure we have an array of responsibilities
          responsibilities = if raw_responsibilities.is_a?(String)
            # If it's a string, it might be a JSON array string, try to parse it
            begin
              JSON.parse(raw_responsibilities)
            rescue
              [ raw_responsibilities ] # If parsing fails, treat it as a single responsibility
            end
          else
            Array(raw_responsibilities)
          end

          # Add bullet points to each responsibility
          pdf.move_down 5  # Space before responsibilities
          responsibilities.each do |responsibility|
            next if responsibility.blank?

            pdf.indent(6) do  # Indent for bullet points
              pdf.formatted_text([
                { text: "• ", size: 10 },
                { text: responsibility.to_s.strip, size: 10 }  # Clean up and use exactly as entered
              ])
            end
            pdf.move_down 4  # Space between bullet points
          end

          pdf.move_down 12  # Space between different work experiences
        end
        end  # End of work experience section if statement

        # Skills Section
        pdf.move_down 15
        pdf.text "SKILLS", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 8

        Array(data[:skills]).each do |skill|
          category = skill[:category].to_s.strip
          details = skill[:details].to_s.strip

          unless category.empty? && details.empty?
            # Draw the category name in bold with a colon
            pdf.font("Helvetica-Bold") do
              pdf.text "#{category}:", size: 10, align: :left
            end

            # Add details on the next line with proper indentation
            pdf.move_down 2
            pdf.indent(15) do
              pdf.text details,
                      size: 10,
                      align: :left,
                      leading: 2
            end

            # Add space between skill categories
            pdf.move_down 6
          end
        end

        # Certifications Section
        pdf.move_down 15
        pdf.text "CERTIFICATIONS", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 8

        Array(data[:certifications]).each do |certification|
          name = certification[:name].to_s.strip
          org = certification[:organization].to_s.strip
          date = certification[:date].to_s.strip

          unless name.empty?
            # Create a bounding box for each certification entry
            pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width, height: 20) do
              # Date on the right
              if date.present?
                pdf.bounding_box([ pdf.bounds.width - 80, pdf.bounds.top ], width: 80) do
                  pdf.text date, size: 10, align: :right
                end
              end

              # Name and organization on the left
              pdf.bounding_box([ 0, pdf.bounds.top ], width: pdf.bounds.width - 90) do
                pdf.font("Helvetica-Bold") { pdf.text "#{name}     ", size: 10 }
                pdf.move_up 11.5
                pdf.indent(pdf.width_of("#{name}     ", size: 10)) do
                  pdf.font("Helvetica") { pdf.text org.to_s, size: 10 }
                end
              end
            end

            pdf.move_down 2
          end
          pdf.move_down 2  # Small space between certifications
        end        # Languages Section
        pdf.move_down 15
        pdf.text "LANGUAGES", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 8
        Array(data[:languages]).each do |language|
          lang = language[:language].to_s.strip
          prof = language[:proficiency].to_s.strip
          unless lang.empty? && prof.empty?
            # Add proficiency level aligned to the right
            pdf.float do
              pdf.text prof, size: 10, align: :right
            end
            # Add language name in bold
            pdf.font("Helvetica-Bold") { pdf.text lang, size: 10 }
          end
          pdf.move_down 2  # Small space between languages
        end
      end
    end

    Rails.logger.info "PDF generated at #{pdf_path}"

    { path: pdf_path.to_s, filename: filename }
  end

  private

  def self.generate_section_title(pdf, title)
    pdf.move_down 10
    pdf.fill_color "000000"
    pdf.text title, size: 13, style: :bold
    pdf.stroke_color "000000"
    pdf.stroke_horizontal_rule
    pdf.fill_color "000000"
    pdf.move_down 12
  end
end
