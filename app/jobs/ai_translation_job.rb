class AiTranslationJob
  include Sidekiq::Job
  
  def perform(work_experience_id)
    # Find the work experience by ID since Sidekiq serializes data
    work_experience = WorkExperience.find(work_experience_id)
    
    # Get the Arabic text from work experience
    arabic_text = work_experience.arabic_description
    
    # Create AI translation record
    translation = work_experience.user.ai_translations.create!(
      arabic_text: arabic_text,
      resume_id: work_experience.resume_id,
      ai_model: 'gpt-3.5-turbo',
      status: 'processing'
    )
    
    begin
      # Process the translation
      service = AiTranslationService.new(arabic_text)
      result = service.translate
      
      # Update the translation record
      translation.update!(
        english_text: result[:english_text],
        translation_quality: result[:quality_score],
        tokens_used: result[:tokens_used],
        status: 'completed'
      )
      
      # Update the work experience with English description
      work_experience.update!(
        english_description: result[:english_text],
        ats_keywords: result[:skills_extracted].map { |s| s[:name] }
      )
      
      # Extract and create skills if they don't exist
      create_skills_from_translation(work_experience, result[:skills_extracted])
      
    rescue => e
      # Handle errors
      translation.update!(
        status: 'failed',
        english_text: "Translation failed: #{e.message}"
      )
      
      # Log the error
      Rails.logger.error "AI Translation failed for work experience #{work_experience.id}: #{e.message}"
      
      # Re-raise the error for Sidekiq to handle
      raise e
    end
  end
  
  private
  
  def create_skills_from_translation(work_experience, skills_data)
    skills_data.each do |skill_data|
      # Check if skill already exists
      existing_skill = work_experience.resume.skills.find_by(name: skill_data[:name])
      
      unless existing_skill
        work_experience.resume.skills.create!(
          name: skill_data[:name],
          level: skill_data[:level],
          category: skill_data[:category]
        )
      end
    end
  end
end 