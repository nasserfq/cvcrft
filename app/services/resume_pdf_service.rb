class ResumePdfService
  def initialize(resume)
    @resume = resume
  end
  
  def generate
    # This is a placeholder implementation
    # In production, you would use Prawn or WickedPDF to generate ATS-friendly PDF
    
    # For now, return a simple HTML that can be converted to PDF
    generate_html_content
  end
  
  private
  
  def generate_html_content
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>#{@resume.complete_name} - CV</title>
        <style>
          /* ATS-Friendly Styling */
          body { 
            font-family: Arial, sans-serif; 
            margin: 0.75in; 
            line-height: 1.15; 
            color: #000000; 
            font-size: 11pt;
            background: white;
          }
          .header { 
            text-align: center; 
            margin-bottom: 15pt; 
            border-bottom: 2pt solid #000000;
            padding-bottom: 8pt;
          }
          .header h1 { 
            font-size: 16pt; 
            font-weight: bold; 
            margin: 0 0 4pt 0; 
            color: #000000; 
            text-transform: uppercase;
            letter-spacing: 1pt;
          }
          .contact-info { 
            font-size: 10pt; 
            color: #000000; 
            margin-bottom: 8pt; 
            font-weight: normal;
          }
          .section { 
            margin-bottom: 12pt; 
            page-break-inside: avoid;
          }
          .section-title { 
            font-size: 12pt; 
            font-weight: bold; 
            color: #000000; 
            border-bottom: 1pt solid #000000; 
            margin-bottom: 6pt; 
            padding-bottom: 2pt;
            text-transform: uppercase;
            letter-spacing: 0.5pt;
          }
          .experience-item { 
            margin-bottom: 8pt; 
            page-break-inside: avoid;
          }
          .experience-header { 
            margin-bottom: 2pt; 
          }
          .position { 
            font-weight: bold; 
            font-size: 11pt; 
            color: #000000; 
            display: inline;
          }
          .company { 
            font-size: 10pt; 
            color: #000000; 
            margin: 0 0 2pt 0; 
            font-style: italic;
          }
          .dates { 
            color: #000000; 
            font-size: 10pt; 
            float: right;
            font-weight: normal;
          }
          .description { 
            margin-top: 3pt; 
            clear: both;
          }
          .description ul { 
            margin: 2pt 0; 
            padding-left: 15pt; 
            list-style-type: disc;
          }
          .description li { 
            margin-bottom: 1pt; 
            font-size: 10pt; 
            line-height: 1.1;
          }
          .education-item { 
            margin-bottom: 8pt; 
            page-break-inside: avoid;
          }
          .education-degree { 
            font-weight: bold; 
            font-size: 11pt; 
            color: #000000; 
            display: inline;
          }
          .education-institution { 
            font-size: 10pt; 
            color: #000000; 
            margin: 0 0 2pt 0; 
            font-style: italic;
          }
          .education-dates { 
            color: #000000; 
            font-size: 10pt; 
            float: right;
            font-weight: normal;
          }
          .skills { 
            margin-bottom: 6pt; 
          }
          .skill-category { 
            font-weight: bold; 
            font-size: 10pt; 
            color: #000000; 
            display: inline;
          }
          .skill-items { 
            font-size: 10pt; 
            color: #000000; 
            display: inline;
          }
          .certification-item { 
            margin-bottom: 3pt; 
            font-size: 10pt; 
          }
          .cert-name { 
            font-weight: bold; 
            display: inline;
          }
          .cert-date { 
            color: #000000; 
            font-size: 10pt; 
            float: right;
            font-weight: normal;
          }
          .language-item { 
            margin-bottom: 2pt; 
            font-size: 10pt; 
          }
          .language-name { 
            font-weight: bold; 
            display: inline;
          }
          .language-proficiency { 
            color: #000000; 
            float: right;
            font-weight: normal;
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
          <p>#{@resume.professional_summary_english.present? ? @resume.professional_summary_english : @resume.professional_summary}</p>
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
    # Remove duplicate work experiences based on job_title, company, and dates
    unique_experiences = @resume.work_experiences.uniq do |exp|
      "#{exp.job_title}-#{exp.company}-#{exp.start_date}-#{exp.end_date}"
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
            [exp.responsibilities]
          end
        else
          [exp.responsibilities.to_s]
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
          <span class="cert-name">#{cert.name} #{cert.organization}</span>
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
