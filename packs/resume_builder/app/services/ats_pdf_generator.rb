require "prawn"
require "prawn/table"
require "fileutils"
require "securerandom"
require_relative "ats_templates/base"
require_relative "ats_templates/classic_01"

class AtsPdfGenerator
  # Only Classic01 is reachable: AtsTemplatePdfService calls this with a
  # hardcoded template of "classic_01" for the "original_classic" preset.
  TEMPLATES = [ AtsTemplates::Classic01 ].freeze

  def self.template_catalog
    TEMPLATES.map { |template| { key: template.key, name: template.display_name, description: template.description } }
  end

  def self.normalize_template_key(template_key)
    key = template_key.to_s
    template_catalog.any? { |template| template[:key] == key } ? key : AtsTemplates::Classic01.key
  end

  PDF_DIR = Rails.root.join("tmp", "pdfs", "generated")

  # Each render gets its own file. Paths used to come from the person's name
  # alone, so two users with the same name (or any two all-Arabic names, which
  # parameterize to "") wrote and read back the same file. Files older than a
  # day are swept so the directory does not grow without bound.
  def self.unique_pdf_path
    FileUtils.mkdir_p(PDF_DIR)
    Dir.glob(PDF_DIR.join("*.pdf")).each do |old|
      File.delete(old) if File.mtime(old) < 1.day.ago
    rescue Errno::ENOENT
      nil
    end
    PDF_DIR.join("#{SecureRandom.uuid}.pdf")
  end

  def self.generate_pdf(resume, data, options = {})
    template_key = normalize_template_key(options[:template] || options["template"])
    template = template_for(template_key).config
    Rails.logger.info "=== ATS PDF GENERATOR STARTED ==="
    Rails.logger.info "Resume: #{resume.id}"
    Rails.logger.info "Template: #{template_key}"

    filename = resume.complete_name.to_s.parameterize.presence&.then { |slug| "#{slug}_resume.pdf" } || "resume.pdf"
    pdf_path = self.unique_pdf_path

    # Set strict encoding to prevent issues with special characters
    Prawn::Document.generate(pdf_path, force_encoding: true, margin: template[:margin]) do |pdf|
      pdf.extend(PdfText::Document)
      # Use core PDF font with encoding set
      pdf.font "Helvetica", enable_smart_quotes: false do
        # Header Section
        pdf.text resume.complete_name.to_s.strip, size: template[:name_size], style: :bold, align: :center
        pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: template[:contact_size], align: :center
        pdf.move_down template[:header_gap]

        # Professional Summary
        pdf.text "PROFESSIONAL SUMMARY", size: template[:section_title_size], style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down template[:title_gap]
        # Use the AI-generated summary first (from data), then fallback to stored resume
        summary = ProfessionalSummaryText.normalize(
          data[:professional_summary].to_s.strip.presence ||
          resume.professional_summary_english.presence ||
          resume.professional_summary.presence
        ) || "No professional summary available"
        pdf.text summary, size: template[:body_size], leading: template[:body_leading]
        pdf.move_down template[:section_gap]

        # Education Section
        pdf.text "EDUCATION", size: template[:section_title_size], style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down template[:title_gap]
        Array(data[:educations]).each do |education|
          # Draw degree and date on the same line
          degree = education[:degree].to_s.strip
          date_text = "#{education[:start_date]} - #{education[:end_date]}"

          pdf.float do
            pdf.text date_text, size: template[:meta_size], align: :right
          end
          pdf.text degree, size: template[:subheading_size], style: :bold

          # Institution on next line
          pdf.text education[:institution].to_s.strip, size: template[:body_size]
          pdf.move_down template[:item_gap]
        end

        # Work Experience Section - Only show if there are work experiences
        if resume.work_experiences.present? && resume.work_experiences.any?
          pdf.text "WORK EXPERIENCE", size: template[:section_title_size], style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down template[:title_gap]

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
            pdf.text date_text, size: template[:meta_size], align: :right
          end

          # Display job title in bold with proper spacing - preserve original case
          pdf.text experience.job_title.to_s.strip, size: template[:subheading_size], style: :bold
          pdf.move_down template[:title_company_gap]
          # Display company name under job title - preserve original case
          pdf.text experience.company.to_s.strip, size: template[:body_size]
          pdf.move_down template[:company_bullet_gap]

          # Get responsibilities from the work experience
          raw_responsibilities = experience.responsibilities.presence || []

          # Ensure we have an array of responsibilities
          responsibilities = if raw_responsibilities.is_a?(String)
            # If it's a string, it might be a JSON array string, try to parse it
            begin
              JSON.parse(raw_responsibilities)
            rescue
              # If parsing fails, split by newlines to get individual responsibilities
              raw_responsibilities.split("\n").map(&:strip).reject(&:blank?)
            end
          else
            Array(raw_responsibilities)
          end

          # Add bullet points to each responsibility
          pdf.move_down template[:bullet_block_gap]
          responsibilities.each do |responsibility|
            next if responsibility.blank?

            pdf.indent(template[:bullet_indent]) do
              pdf.formatted_text([
                { text: "• ", size: template[:body_size] },
                { text: responsibility.to_s.strip, size: template[:body_size] }
              ])
            end
            pdf.move_down template[:bullet_gap]
          end

          pdf.move_down template[:experience_gap]
        end
        end  # End of work experience section if statement

        # Skills Section
        pdf.move_down template[:section_gap]
        pdf.text "SKILLS", size: template[:section_title_size], style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down template[:title_gap]

        Array(data[:skills]).each do |skill|
          category = skill[:category].to_s.strip
          details = skill[:details].to_s.strip

          unless category.empty? && details.empty?
            # Draw the category name in bold with a colon
            pdf.font("Helvetica-Bold") do
              pdf.text "#{category}:", size: template[:body_size], align: :left
            end

            # Add details on the next line with proper indentation
            pdf.move_down template[:detail_gap]
            pdf.indent(template[:details_indent]) do
              pdf.text details,
                      size: template[:body_size],
                      align: :left,
                      leading: template[:body_leading]
            end

            # Add space between skill categories
            pdf.move_down template[:item_gap]
          end
        end

        # Certifications Section
        pdf.move_down template[:section_gap]
        pdf.text "CERTIFICATIONS", size: template[:section_title_size], style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down template[:title_gap]

        Array(data[:certifications]).each do |certification|
          name = certification[:name].to_s.strip
          org = certification[:organization].to_s.strip
          date = certification[:date].to_s.strip

          unless name.empty?
            # Date aligned to right
            if date.present?
              pdf.float do
                pdf.text date, size: template[:meta_size], align: :right
              end
            end

            # Name in bold, then organization in regular font on same line
            pdf.font("Helvetica-Bold") { pdf.text "#{name}  ", size: template[:body_size], inline_format: false }
            if org.present?
              pdf.move_up(template[:cert_line_up])
              name_width = pdf.width_of("#{name}", size: template[:body_size]) + template[:cert_org_indent]
              pdf.indent(name_width) do
                pdf.font("Helvetica") { pdf.text org, size: template[:body_size] }
              end
            end

            pdf.move_down template[:item_gap]
          end
        end        # Languages Section
        pdf.move_down template[:section_gap]
        pdf.text "LANGUAGES", size: template[:section_title_size], style: :bold
        pdf.stroke_horizontal_rule
        pdf.move_down template[:title_gap]
        Array(data[:languages]).each do |language|
          lang = language[:language].to_s.strip
          prof = language[:proficiency].to_s.strip
          unless lang.empty? && prof.empty?
            # Add proficiency level aligned to the right
            pdf.float do
              pdf.text prof, size: template[:meta_size], align: :right
            end
            # Add language name in bold
            pdf.font("Helvetica-Bold") { pdf.text lang, size: template[:body_size] }
          end
          pdf.move_down template[:detail_gap]
        end
      end
    end

    Rails.logger.info "PDF generated at #{pdf_path}"

    { path: pdf_path.to_s, filename: filename }
  end

  private

  def self.template_for(template_key)
    TEMPLATES.find { |template| template.key == template_key } || AtsTemplates::Classic01
  end

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
