class ResumePdfService
  def initialize(resume, generated_content = nil)
    @resume = resume
    @generated_content = generated_content
  end

  def generate
    # This is a placeholder implementation
    # In production, you would use Prawn or WickedPDF to generate ATS-friendly PDF

    # For now, return a simple HTML that can be converted to PDF
    generate_html_content
  end

  private

  def generate_html_content
    Rails.logger.info "=== RESUME PDF SERVICE ==="
    Rails.logger.info "Generated Content Present: #{@generated_content.present?}"
    Rails.logger.info "Generated Content: #{@generated_content&.truncate(100)}"
    Rails.logger.info "Resume Professional Summary: #{@resume.professional_summary&.truncate(100)}"
    Rails.logger.info "Resume Professional Summary English: #{@resume.professional_summary_english&.truncate(100)}"

    # Determine which content to use
    content_to_use = if @generated_content.present?
      @generated_content
    elsif @resume.professional_summary.present?
      @resume.professional_summary
    else
      @resume.professional_summary_english
    end

    Rails.logger.info "Content to use for PDF: #{content_to_use&.truncate(100)}"

    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>#{@resume.complete_name} - CV</title>
        <style>
          /* ATS-Friendly Styling */
          body {#{' '}
            font-family: Arial, sans-serif;#{' '}
            margin: 1in 0.5in 0.5in 0.5in;#{' '}
            line-height: 1.3;#{' '}
            color: #000000;#{' '}
            font-size: 11pt;#{' '}
            background: white;#{' '}
            word-wrap: break-word;#{' '}
            overflow-wrap: break-word;
          }
          .header {#{' '}
            text-align: center;#{' '}
            margin-top: 0;#{' '}
            margin-bottom: 20pt;#{' '}
            padding-top: 0;#{' '}
            border-bottom: 1pt solid #000000;
            padding-bottom: 8pt;
          }
          .header h1 {#{' '}
            font-size: 18pt;#{' '}
            font-weight: bold;#{' '}
            margin: 0 0 6pt 0;#{' '}
            color: #000000;#{' '}
            text-transform: none;
          }
          .contact-info {#{' '}
            font-size: 11pt;#{' '}
            color: #000000;#{' '}
            margin-bottom: 0;#{' '}
            font-weight: normal;
          }
          .section {#{' '}
            margin-top: 15pt;#{' '}
            margin-bottom: 15pt;#{' '}
            page-break-inside: avoid;
          }
          .section-title {#{' '}
            font-size: 12pt;#{' '}
            font-weight: bold;#{' '}
            color: #000000;#{' '}
            border-bottom: 1pt solid #000000;#{' '}
            margin-bottom: 8pt;#{' '}
            padding-bottom: 2pt;
            text-transform: none;
            letter-spacing: normal;
          }
          .experience-item {#{' '}
            margin-bottom: 12pt;#{' '}
            page-break-inside: avoid;#{' '}
            word-wrap: break-word;#{' '}
            overflow-wrap: break-word;#{' '}
            clear: both;
          }
          .experience-header {#{' '}
            margin-bottom: 2pt;#{' '}
            clear: both;#{' '}
            overflow: hidden;
          }
          .position {#{' '}
            font-weight: bold;#{' '}
            font-size: 11pt;#{' '}
            color: #000000;#{' '}
            float: left;#{' '}
            width: 70%;
          }
          .company {#{' '}
            font-size: 10pt;#{' '}
            color: #000000;#{' '}
            margin: 0 0 2pt 0;#{' '}
            font-style: normal;#{' '}
            float: left;#{' '}
            clear: left;#{' '}
            width: 70%;
          }
          .dates {#{' '}
            color: #000000;#{' '}
            font-size: 10pt;#{' '}
            float: right;#{' '}
            font-weight: normal;#{' '}
            width: 25%;#{' '}
            text-align: right;
          }
          .description {#{' '}
            margin-top: 3pt;#{' '}
            clear: both;#{' '}
            word-wrap: break-word;#{' '}
            overflow-wrap: break-word;#{' '}
            float: left;#{' '}
            width: 100%;
          }
          .description ul {#{' '}
            margin: 2pt 0;#{' '}
            padding-left: 15pt;#{' '}
            list-style-type: disc;#{' '}
            word-wrap: break-word;#{' '}
            overflow-wrap: break-word;#{' '}
            clear: both;
          }
          .description li {#{' '}
            margin-bottom: 2pt;#{' '}
            font-size: 10pt;#{' '}
            line-height: 1.2;#{' '}
            word-wrap: break-word;#{' '}
            overflow-wrap: break-word;#{' '}
            hyphens: auto;#{' '}
            max-width: 100%;#{' '}
            clear: both;
          }
          .education-item {#{' '}
            margin-bottom: 8pt;#{' '}
            page-break-inside: avoid;#{' '}
            clear: both;#{' '}
            overflow: hidden;
          }
          .education-degree {#{' '}
            font-weight: bold;#{' '}
            font-size: 11pt;#{' '}
            color: #000000;#{' '}
            float: left;#{' '}
            width: 70%;
          }
          .education-institution {#{' '}
            font-size: 10pt;#{' '}
            color: #000000;#{' '}
            margin: 0 0 2pt 0;#{' '}
            font-style: normal;#{' '}
            float: left;#{' '}
            clear: left;#{' '}
            width: 70%;
          }
          .education-dates {#{' '}
            color: #000000;#{' '}
            font-size: 10pt;#{' '}
            float: right;#{' '}
            font-weight: normal;#{' '}
            width: 25%;#{' '}
            text-align: right;
          }
          .skills {#{' '}
            margin-bottom: 6pt;#{' '}
          }
          .skill-category {#{' '}
            font-weight: bold;#{' '}
            font-size: 10pt;#{' '}
            color: #000000;#{' '}
            display: inline;
          }
          .skill-items {#{' '}
            font-size: 10pt;#{' '}
            color: #000000;#{' '}
            display: inline;
          }
          .certification-item {#{' '}
            margin-bottom: 3pt;#{' '}
            font-size: 10pt;#{' '}
            clear: both;#{' '}
            overflow: hidden;
          }
          .cert-name {#{' '}
            font-weight: bold;#{' '}
            float: left;#{' '}
            width: 70%;
          }
          .cert-org {#{' '}
            font-weight: normal;#{' '}
            float: left;#{' '}
            clear: left;#{' '}
            width: 70%;
          }
          .cert-date {#{' '}
            color: #000000;#{' '}
            font-size: 10pt;#{' '}
            float: right;#{' '}
            font-weight: normal;#{' '}
            width: 25%;#{' '}
            text-align: right;
          }
          .language-item {#{' '}
            margin-bottom: 2pt;#{' '}
            font-size: 10pt;#{' '}
          }
          .language-name {#{' '}
            font-weight: bold;#{' '}
            display: inline;
          }
          .language-proficiency {#{' '}
            color: #000000;#{' '}
            float: right;
            font-weight: normal;
          }
          /* Enhanced multi-page styling */
          @page {
            margin: 1in 0.5in 0.5in 0.5in;
            size: A4;
            @top-center { content: ""; }
            @bottom-center { content: ""; }
          }
          @page :first {
            margin-top: 1in;
            margin-bottom: 0.5in;
            margin-left: 0.5in;
            margin-right: 0.5in;
          }
          @page :left {
            margin-left: 0.5in;
            margin-right: 0.5in;
            margin-top: 1in;
            margin-bottom: 0.5in;
          }
          @page :right {
            margin-left: 0.5in;
            margin-right: 0.5in;
            margin-top: 1in;
            margin-bottom: 0.5in;
          }
          /* Better page break control for multi-page resumes */
          .page-break-before {
            page-break-before: always;
          }
          .page-break-after {
            page-break-after: always;
          }
          .page-break-inside-avoid {
            page-break-inside: avoid;
          }
          /* Prevent orphaned section titles */
          .section-title {
            page-break-after: avoid;
            orphans: 2;
            widows: 2;
          }
          /* Better spacing for multi-page content */
          .section {
            margin-top: 15pt;
            margin-bottom: 15pt;
            page-break-inside: avoid;
            orphans: 2;
            widows: 2;
          }
          /* Ensure consistent spacing on all pages */
          .experience-item {
            margin-bottom: 8pt;
            page-break-inside: avoid;
            orphans: 2;
            widows: 2;
          }
          .education-item {
            margin-bottom: 8pt;
            page-break-inside: avoid;
            orphans: 2;
            widows: 2;
          }
          /* Multi-page content flow */
          .multi-page-content {
            page-break-inside: auto;
          }
          /* ATS-specific overrides */
          .clearfix::after {
            content: "";
            display: table;
            clear: both;
          }
          /* Ensure no fancy formatting that ATS can't read */
          * {
            box-sizing: border-box;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>#{@resume.complete_name.upcase}</h1>
          <div class="contact-info">
            <p>#{@resume.email} | #{@resume.phone_number} | #{@resume.city}, #{@resume.country}</p>
          </div>
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Professional Summary</div>
          <p>#{content_to_use}</p>
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Work Experience</div>
          #{generate_work_experience_html}
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Education</div>
          #{generate_education_html}
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Skills</div>
          #{generate_skills_html}
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Certificates</div>
          #{generate_certifications_html}
        </div>
      #{'  '}
        <div class="section">
          <div class="section-title">Languages</div>
          #{generate_languages_html}
        </div>
      </body>
      </html>
    HTML
  end

  def generate_work_experience_html
    # Order work experiences: current jobs first, then by start_date descending (newest first)
    # Remove duplicate work experiences based on job_title, company, and dates
    unique_experiences = @resume.work_experiences.uniq do |exp|
      "#{exp.job_title}-#{exp.company}-#{exp.start_date}-#{exp.end_date}"
    end.sort do |a, b|
      Rails.logger.info "Sorting work experiences: #{a.job_title} (#{a.start_date}) vs #{b.job_title} (#{b.start_date})"
      # Check if jobs are current (Present)
      a_is_current = a.is_current || a.end_date.blank?
      b_is_current = b.is_current || b.end_date.blank?

      # If one is current and the other isn't, current job goes first
      if a_is_current && !b_is_current
        -1
      elsif !a_is_current && b_is_current
        1
      else
        # If both are current or both are not current, sort by start_date descending
        if a.start_date.present? && b.start_date.present?
          begin
            Date.parse(b.start_date) <=> Date.parse(a.start_date)
          rescue ArgumentError, TypeError
            # If date parsing fails, compare as strings
            b.start_date <=> a.start_date
          end
        else
          0
        end
      end
    end

    unique_experiences.map do |exp|
      start_date = exp.start_date.present? ? exp.start_date : "N/A"
      # Show "Present" if it's marked as current or if there's no end date (assuming ongoing)
      end_date = if exp.is_current || exp.end_date.blank?
        "Present"
      else
        exp.end_date
      end

      # Parse responsibilities properly and remove duplicates
      responsibilities_html = ""
      if exp.responsibilities.present?
        responsibilities_list = if exp.responsibilities.is_a?(Array)
          exp.responsibilities
        elsif exp.responsibilities.is_a?(String)
          begin
            JSON.parse(exp.responsibilities)
          rescue JSON::ParserError
            [ exp.responsibilities ]
          end
        else
          [ exp.responsibilities.to_s ]
        end

        # Format as bullet points (remove duplicates for cleaner CV)
        responsibilities_to_display = responsibilities_list.compact.reject(&:blank?).uniq
        if responsibilities_to_display.any?
          responsibilities_html = "<ul class='description'>"
          responsibilities_to_display.each do |resp|
            responsibilities_html += "<li>#{resp}</li>"
          end
          responsibilities_html += "</ul>"
        end
      end

      <<~HTML
        <div class="experience-item clearfix">
          <div class="experience-header">
            <span class="position">#{exp.job_title}</span>
            <span class="dates">#{start_date} - #{end_date}</span>
          </div>
          <div class="company">#{exp.company}</div>
          #{responsibilities_html}
        </div>
      HTML
    end.join
  end

  def generate_skills_html
    # Remove duplicate skills based on category and skill_names
    unique_skills = @resume.skills.uniq do |skill|
      "#{skill.category}-#{skill.skill_names}"
    end

    skills_by_category = unique_skills.group_by(&:category)

    skills_by_category.map do |category, skills|
      skill_names = skills.flat_map do |skill|
        if skill.skill_names.is_a?(Array)
          skill.skill_names
        elsif skill.skill_names.is_a?(String)
          begin
            JSON.parse(skill.skill_names)
          rescue JSON::ParserError
            [ skill.skill_names ].compact
          end
        else
          [ skill.skill_names ].compact
        end
      end.compact.uniq.reject(&:blank?)
      next if skill_names.empty?

      <<~HTML
          <div class="skills">
          <span class="skill-category">#{category}:</span> <span class="skill-items">#{skill_names.join(', ')}</span>
        </div>
      HTML
    end.compact.join
  end

  def generate_education_html
    # Remove duplicate education entries based on degree, institution, and dates
    unique_educations = @resume.educations.uniq do |edu|
      "#{edu.degree}-#{edu.institution}-#{edu.start_date}-#{edu.end_date}"
    end

    unique_educations.map do |edu|
      start_date = edu.start_date.present? ? edu.start_date : "N/A"
      # Show "Present" if it's marked as current or if there's no end date (assuming ongoing)
      end_date = if edu.is_current || edu.end_date.blank?
        "Present"
      else
        edu.end_date
      end
      gpa_info = edu.gpa.present? ? " (GPA: #{edu.gpa})" : ""

      <<~HTML
        <div class="education-item clearfix">
          <div class="education-header">
            <span class="education-degree">#{edu.degree}</span>
            <span class="education-dates">#{start_date} - #{end_date}</span>
          </div>
          <div class="education-header">
            <span class="education-institution">#{edu.institution}</span>
            <span class="education-dates">#{gpa_info}</span>
          </div>
        </div>
      HTML
    end.join
  end

  def generate_certifications_html
    # Remove duplicate certifications based on name, organization, and date
    unique_certifications = @resume.certifications.uniq do |cert|
      "#{cert.name}-#{cert.organization}-#{cert.date}"
    end

    unique_certifications.map do |cert|
      date_info = cert.date.present? ? " #{cert.date}" : ""

      <<~HTML
        <div class="certification-item clearfix">
          <span class="cert-name">#{cert.name}</span> <span class="cert-org">#{cert.organization}</span>
          <span class="cert-date">#{date_info.strip}</span>
        </div>
      HTML
    end.join
  end

  def generate_languages_html
    # Remove duplicate languages based on language and proficiency
    unique_languages = @resume.languages.uniq do |lang|
      "#{lang.language}-#{lang.proficiency}"
    end

    unique_languages.map do |lang|
      <<~HTML
        <div class="language-item clearfix">
          <span class="language-name">#{lang.language}</span>
          <span class="language-proficiency">#{lang.proficiency}</span>
        </div>
      HTML
    end.join
  end
end
