require "administrate/field/base"

class CvBuildingStatsField < Administrate::Field::Base
  def to_s
    data
  end

  def cv_building_summary
    return "No CVs built yet" if data.resume_count.zero?
    
    stats = []
    stats << "#{data.resume_count} CV#{'s' if data.resume_count != 1} built"
    stats << "#{data.resumes_with_work_experience} with work experience"
    stats << "#{data.resumes_with_skills} with skills"
    stats << "#{data.resumes_with_ats_score} with ATS scores"
    
    if data.average_ats_score > 0
      stats << "Avg ATS Score: #{data.average_ats_score}"
    end
    
    stats.join(" • ")
  end
end
