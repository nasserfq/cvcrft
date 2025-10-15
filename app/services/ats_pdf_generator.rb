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

    Prawn::Document.generate(pdf_path) do |pdf|
      pdf.font "Helvetica" do
        # Header Section
        pdf.text resume.complete_name.to_s.strip, size: 20, style: :bold, align: :center
        pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: 10, align: :center
        pdf.move_down 20

        # Professional Summary
        pdf.text "PROFESSIONAL SUMMARY", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 10
        # Use the OpenAI enhanced/translated version if available, fallback to original
        summary = resume.professional_summary_english.presence ||
                 data[:professional_summary].to_s.strip
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

        # Work Experience Section
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
          # Draw job title and date on the same line
          job_title = experience.job_title.to_s.strip
          date_text = "#{experience.start_date} - #{experience.is_current ? 'Present' : experience.end_date}"

          pdf.float do
            pdf.text date_text, size: 10, align: :right
          end
          pdf.text job_title, size: 11, style: :bold

          # Company on next line
          pdf.text experience.company.to_s.strip, size: 10

          # Use English description if available
          description = experience.english_description.presence || experience.responsibilities

          # Process responsibilities
          responsibilities = if description.is_a?(Array)
            description
          else
            description.to_s.split(/[\n,]/).map(&:strip)
          end

          # Clean and format responsibilities
          responsibilities = responsibilities
            .map(&:strip)
            .reject(&:empty?)
            .map { |r| r.gsub(/[\[\]"']/, "") }  # Remove brackets and quotes

          # Display each responsibility with bullet point
          responsibilities.each do |responsibility|
            pdf.formatted_text([
              { text: "• ", size: 10 },
              { text: responsibility, size: 10 }
            ])
          end

          pdf.move_down 10
        end

        # Skills Section
        pdf.move_down 15
        pdf.text "SKILLS", size: 13, style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down 8
        Array(data[:skills]).each do |skill|
          category = skill[:category].to_s.strip
          details = skill[:details].to_s.strip
          unless category.empty? && details.empty?
            # First write the bold category with colon using Helvetica-Bold
            pdf.font("Helvetica-Bold") do
              pdf.text "#{category}:  ", size: 10  # Added extra space after colon
            end

            # Move up and add the details with proper spacing
            pdf.move_up 11.5
            pdf.indent(pdf.width_of("#{category}:  ", size: 10)) do  # Adjusted indent to match extra space
              pdf.text details, size: 10
            end
          end
          pdf.move_down 4  # Space between skill lines
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
            # Handle the date with float to align it to the right
            if date.present?
              pdf.float do
                pdf.text date, size: 10, align: :right
              end
            end

            # Write certification name in bold
            pdf.font("Helvetica-Bold") { pdf.text name, size: 10 }
            pdf.move_up 11.5
            pdf.indent(pdf.width_of(name + " ", size: 10)) do
              pdf.text " #{org}", size: 10
            end
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
