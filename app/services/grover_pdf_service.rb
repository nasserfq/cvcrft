class GroverPdfService
  def initialize(resume)
    @resume = resume
  end

  def generate_pdf
    html_content = generate_html_content
    
    # Grover expects only HTML content as argument
    Grover.new(html_content).to_pdf
  end

  private

  def generate_html_content
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>#{@resume.complete_name} - Resume</title>
        <style>
          #{css_styles}
        </style>
      </head>
      <body>
        #{html_content}
      </body>
      </html>
    HTML
  end

  def html_content
    <<~HTML
      <div class="header">
        <h1>#{@resume.complete_name}</h1>
        <div class="contact-info">
          #{@resume.email} | #{@resume.phone_number} | #{@resume.city}, #{@resume.country}
        </div>
      </div>

      #{professional_summary_section}
      #{work_experience_section}
      #{education_section}
      #{skills_section}
      #{certifications_section}
      #{languages_section}
    HTML
  end

  def professional_summary_section
    return '' unless @resume.professional_summary_english.present?

    <<~HTML
      <div class="section">
        <h2 class="section-title">PROFESSIONAL SUMMARY</h2>
        <p>#{@resume.professional_summary_english}</p>
      </div>
    HTML
  end

  def work_experience_section
    return '' unless @resume.work_experiences.any?

    sorted_experiences = @resume.work_experiences.sort do |a, b|
      # Prioritize current jobs first
      a_current = a.is_current || a.end_date.blank?
      b_current = b.is_current || b.end_date.blank?
      
      if a_current && !b_current
        -1
      elsif !a_current && b_current
        1
      else
        # Sort by start_date descending (newest first)
        begin
          Date.parse(b.start_date) <=> Date.parse(a.start_date)
        rescue ArgumentError, TypeError
          b.start_date <=> a.start_date
        end
      end
    end

    experiences_html = sorted_experiences.map do |exp|
      <<~HTML
        <div class="experience-item">
          <div class="experience-header">
            <div class="position">#{exp.job_title}</div>
            <div class="dates">#{format_dates(exp)}</div>
          </div>
          <div class="company">#{exp.company}</div>
          #{responsibilities_html(exp)}
        </div>
      HTML
    end.join

    <<~HTML
      <div class="section">
        <h2 class="section-title">WORK EXPERIENCE</h2>
        #{experiences_html}
      </div>
    HTML
  end

  def responsibilities_html(experience)
    return '' unless experience.responsibilities.present?

    # Handle responsibilities as either JSON string or array
    responsibilities = if experience.responsibilities.is_a?(String)
                        begin
                          JSON.parse(experience.responsibilities)
                        rescue JSON::ParserError
                          experience.responsibilities.split(',').map(&:strip)
                        end
                      else
                        experience.responsibilities
                      end

    responsibilities = responsibilities.filter_map(&:strip).reject(&:blank?)
    return '' if responsibilities.empty?

    # Use simple text with manual bullets instead of HTML lists
    bullets_html = responsibilities.map do |resp|
      "<div class='bullet-point'>• #{resp}</div>"
    end.join

    <<~HTML
      <div class="description">
        #{bullets_html}
      </div>
    HTML
  end

  def education_section
    return '' unless @resume.educations.any?

    education_html = @resume.educations.map do |edu|
      <<~HTML
        <div class="education-item">
          <div class="education-degree">#{edu.degree}</div>
          <div class="education-institution">#{edu.institution}</div>
          <div class="education-dates">#{format_education_dates(edu)}</div>
        </div>
      HTML
    end.join

    <<~HTML
      <div class="section">
        <h2 class="section-title">EDUCATION</h2>
        #{education_html}
      </div>
    HTML
  end

  def skills_section
    return '' unless @resume.skills.any?

    skills_html = @resume.skills.group_by(&:category).map do |category, skills|
      skill_names = skills.flat_map(&:skill_names).compact.uniq.join(', ')
      <<~HTML
        <div class="skill-category">
          <strong>#{category}:</strong> #{skill_names}
        </div>
      HTML
    end.join

    <<~HTML
      <div class="section">
        <h2 class="section-title">SKILLS</h2>
        <div class="skills">
          #{skills_html}
        </div>
      </div>
    HTML
  end

  def certifications_section
    return '' unless @resume.certifications.any?

    certs_html = @resume.certifications.map do |cert|
      <<~HTML
        <div class="certification-item">
          <div class="cert-name">#{cert.name}</div>
          <div class="cert-org">#{cert.organization}</div>
          <div class="cert-date">#{cert.date}</div>
        </div>
      HTML
    end.join

    <<~HTML
      <div class="section">
        <h2 class="section-title">CERTIFICATIONS</h2>
        #{certs_html}
      </div>
    HTML
  end

  def languages_section
    return '' unless @resume.languages.any?

    languages_html = @resume.languages.map do |lang|
      <<~HTML
        <div class="language-item">
          <strong>#{lang.language}:</strong> #{lang.proficiency}
        </div>
      HTML
    end.join

    <<~HTML
      <div class="section">
        <h2 class="section-title">LANGUAGES</h2>
        #{languages_html}
      </div>
    HTML
  end

  def format_dates(experience)
    return '' unless experience.start_date.present?

    start_date = experience.start_date
    end_date = experience.is_current ? 'Present' : experience.end_date
    "#{start_date} - #{end_date}"
  end

  def format_education_dates(education)
    return '' unless education.start_date.present?

    start_date = education.start_date
    end_date = education.is_current ? 'Present' : education.end_date
    "#{start_date} - #{end_date}"
  end

  def css_styles
    <<~CSS
      @page {
        margin-top: 2in;
        margin-bottom: 1in;
        margin-left: 0.75in;
        margin-right: 0.75in;
      }
      
      body {
        font-family: Arial, sans-serif;
        font-size: 11pt;
        line-height: 1.3;
        color: #000000;
        margin: 2in 0.75in 1in 0.75in;
        word-wrap: break-word;
        overflow-wrap: break-word;
      }
      
      .header {
        text-align: center;
        margin-bottom: 10pt;
        padding-top: 10pt;
        padding-bottom: 6pt;
        border-bottom: 1pt solid #000000;
      }
      
      .header h1 {
        font-size: 18pt;
        font-weight: bold;
        margin: 0 0 4pt 0;
        text-transform: none;
        letter-spacing: 0.5pt;
        color: #000000;
      }
      
      .contact-info {
        font-size: 11pt;
        color: #000000;
      }
      
      .section-title {
        font-size: 12pt;
        font-weight: bold;
        text-transform: uppercase;
        letter-spacing: 0.5pt;
        margin-bottom: 4pt;
        padding-bottom: 1pt;
        border-bottom: 1pt solid #000000;
        color: #000000;
      }
      
      .section {
        margin-top: 12pt;
        margin-bottom: 15pt;
        page-break-inside: avoid;
      }
      
      .experience-item {
        margin-bottom: 8pt;
        page-break-inside: avoid;
        word-wrap: break-word;
        overflow-wrap: break-word;
        clear: both;
      }
      
      .experience-header {
        margin-bottom: 2pt;
        clear: both;
        overflow: hidden;
      }
      
      .position {
        font-weight: bold;
        font-size: 11pt;
        color: #000000;
        float: left;
        width: 70%;
      }
      
      .company {
        font-size: 10pt;
        color: #000000;
        margin: 0 0 3pt 0;
        font-style: normal;
        float: left;
        clear: left;
        width: 70%;
      }
      
      .dates {
        color: #000000;
        font-size: 10pt;
        float: right;
        font-weight: normal;
        width: 25%;
        text-align: right;
      }
      
      .description {
        margin-top: 2pt;
        clear: both;
        word-wrap: break-word;
        overflow-wrap: break-word;
        float: left;
        width: 100%;
      }
      
      .bullet-point {
        margin-bottom: 3pt;
        font-size: 10pt;
        line-height: 1.2;
        word-wrap: break-word;
        overflow-wrap: break-word;
        hyphens: auto;
        max-width: 100%;
        clear: both;
        text-align: justify;
        padding-left: 0pt;
        margin-left: 0pt;
        text-indent: 0pt;
      }
      
      .education-item {
        margin-bottom: 6pt;
        page-break-inside: avoid;
        clear: both;
        overflow: hidden;
      }
      
      .education-degree {
        font-weight: bold;
        font-size: 11pt;
        color: #000000;
        float: left;
        width: 70%;
      }
      
      .education-institution {
        font-size: 10pt;
        color: #000000;
        margin: 0 0 2pt 0;
        font-style: normal;
        float: left;
        clear: left;
        width: 70%;
      }
      
      .education-dates {
        color: #000000;
        font-size: 10pt;
        float: right;
        font-weight: normal;
        width: 25%;
        text-align: right;
      }
      
      .skills {
        margin-bottom: 4pt;
      }
      
      .skill-category {
        margin-bottom: 1pt;
        font-size: 10pt;
        line-height: 1.1;
        color: #000000;
      }
      
      .certification-item {
        margin-bottom: 3pt;
        clear: both;
        overflow: hidden;
      }
      
      .cert-name {
        font-weight: bold;
        font-size: 11pt;
        color: #000000;
        float: left;
        width: 70%;
      }
      
      .cert-org {
        font-size: 10pt;
        color: #000000;
        margin: 0 0 2pt 0;
        font-style: normal;
        float: left;
        clear: left;
        width: 70%;
      }
      
      .cert-date {
        color: #000000;
        font-size: 10pt;
        float: right;
        font-weight: normal;
        width: 25%;
        text-align: right;
      }
      
      .language-item {
        margin-bottom: 2pt;
        font-size: 10pt;
        color: #000000;
      }
    CSS
  end
end
