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
        <title>#{@resume.title} - CV</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .header { text-align: center; margin-bottom: 30px; }
          .section { margin-bottom: 25px; }
          .section-title { font-size: 18px; font-weight: bold; border-bottom: 2px solid #333; margin-bottom: 15px; }
          .experience-item { margin-bottom: 20px; }
          .company { font-weight: bold; }
          .position { font-style: italic; color: #666; }
          .dates { color: #888; font-size: 14px; }
          .description { margin-top: 10px; line-height: 1.5; }
          .skills { display: flex; flex-wrap: wrap; gap: 10px; }
          .skill { background: #f0f0f0; padding: 5px 10px; border-radius: 15px; font-size: 14px; }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>#{@resume.user.name}</h1>
          <p>#{@resume.target_position}</p>
          <p>#{@resume.user.email}</p>
        </div>
        
        <div class="section">
          <div class="section-title">Professional Summary</div>
          <p>#{@resume.summary}</p>
        </div>
        
        <div class="section">
          <div class="section-title">Work Experience</div>
          #{generate_work_experience_html}
        </div>
        
        <div class="section">
          <div class="section-title">Skills</div>
          #{generate_skills_html}
        </div>
        
        <div class="section">
          <div class="section-title">ATS Optimization</div>
          <p>ATS Score: #{@resume.ats_score || 'Not calculated'}</p>
          <p>Keywords: #{@resume.ats_keywords&.join(', ') || 'None'}</p>
        </div>
      </body>
      </html>
    HTML
  end
  
  def generate_work_experience_html
    @resume.work_experiences.chronological.map do |exp|
      <<~HTML
        <div class="experience-item">
          <div class="company">#{exp.company}</div>
          <div class="position">#{exp.position}</div>
          <div class="dates">#{exp.start_date.strftime('%B %Y')} - #{exp.end_date ? exp.end_date.strftime('%B %Y') : 'Present'}</div>
          <div class="description">#{exp.english_description || exp.arabic_description}</div>
        </div>
      HTML
    end.join
  end
  
  def generate_skills_html
    skills_by_category = @resume.skills.group_by(&:category)
    
    skills_by_category.map do |category, skills|
      <<~HTML
        <div style="margin-bottom: 15px;">
          <strong>#{category.titleize}:</strong>
          <div class="skills">
            #{skills.map { |skill| "<span class='skill'>#{skill.display_name}</span>" }.join}
          </div>
        </div>
      HTML
    end.join
  end
end 