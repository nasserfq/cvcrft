class AzureOpenaiService
  def initialize(user_id, resume_id = nil)
    @user_id = user_id
    @resume_id = resume_id
  end

  # Translate Arabic text to English
  def translate_text(arabic_text, options = {})
    # Ensure all options are JSON-compatible for Sidekiq 8.0.4
    json_options = options.transform_values do |value|
      case value
      when Symbol
        value.to_s
      when Hash
        value.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
      else
        value
      end
    end

    # Enqueue the background job
    AiTranslationJob.perform_async(
      arabic_text,
      @user_id,
      @resume_id,
      json_options
    )

    # Return a response indicating the job was queued
    {
      status: "queued",
      message: "Translation job has been queued and will be processed in the background",
      job_id: SecureRandom.uuid # You might want to store this for tracking
    }
  end

  # Translate work experience description
  def translate_work_experience(work_experience_id, arabic_text, options = {})
    options[:work_experience_id] = work_experience_id

    translate_text(arabic_text, options)
  end

  # Translate professional summary
  def translate_professional_summary(arabic_text, options = {})
    # Convert symbol keys to string keys for Sidekiq 8.0.4 compatibility
    string_options = options.transform_keys(&:to_s)
    string_options["professional_summary"] = true

    translate_text(arabic_text, string_options)
  end

  # Get translation status
  def get_translation_status(translation_id)
    translation = AiTranslation.find(translation_id)

    {
      id: translation.id,
      status: translation.status,
      arabic_text: translation.arabic_text,
      english_text: translation.english_text,
      translation_quality: translation.translation_quality,
      tokens_used: translation.tokens_used,
      created_at: translation.created_at,
      updated_at: translation.updated_at,
      metadata: translation.metadata
    }
  end

  # Get all translations for a user
  def get_user_translations(limit = 10)
    user = User.find(@user_id)

    user.ai_translations
        .order(created_at: :desc)
        .limit(limit)
        .map do |translation|
      get_translation_status(translation.id)
    end
  end

  # Get all translations for a resume
  def get_resume_translations(limit = 10)
    return [] unless @resume_id

    AiTranslation.where(resume_id: @resume_id)
                .order(created_at: :desc)
                .limit(limit)
                .map do |translation|
      get_translation_status(translation.id)
    end
  end

  # Retry failed translation
  def retry_translation(translation_id)
    translation = AiTranslation.find(translation_id)

    return { error: "Translation is not in failed status" } unless translation.status == "failed"

    # Reset status and retry
    translation.update!(status: "processing")

    # Re-enqueue the job
    AiTranslationJob.perform_async(
      translation.arabic_text,
      translation.user_id,
      translation.resume_id,
      translation.metadata
    )

    {
      status: "retrying",
      message: "Translation job has been re-queued",
      translation_id: translation.id
    }
  end

  # Cancel pending translation
  def cancel_translation(translation_id)
    translation = AiTranslation.find(translation_id)

    return { error: "Translation cannot be cancelled" } unless translation.status == "processing"

    translation.update!(status: "cancelled")

    {
      status: "cancelled",
      message: "Translation has been cancelled",
      translation_id: translation.id
    }
  end

  # Get translation statistics
  def get_translation_stats
    user = User.find(@user_id)

    translations = user.ai_translations

    {
      total_translations: translations.count,
      completed: translations.where(status: "completed").count,
      failed: translations.where(status: "failed").count,
      processing: translations.where(status: "processing").count,
      cancelled: translations.where(status: "cancelled").count,
      total_tokens_used: translations.sum(:tokens_used) || 0,
      average_quality: translations.where.not(translation_quality: nil).average(:translation_quality) || 0
    }
  end

  # CV Generation methods
  def generate_cv(job_description, options = {})
    # Ensure all options are JSON-compatible for Sidekiq 8.0.4
    json_options = options.transform_keys(&:to_s).transform_values do |value|
      case value
      when Symbol
        value.to_s
      when Hash
        value.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
      else
        value
      end
    end

    # Create CV generation record first
    user = User.find(@user_id)
    cv_generation = user.cv_generations.create!(
      job_description: job_description,
      resume_id: @resume_id,
      ai_model: "gpt-4.1-mini",
      status: "processing",
      metadata: json_options
    )

    # Enqueue the CV generation job
    CvGeneratorJob.perform_async(
      job_description,
      @user_id,
      @resume_id,
      json_options
    )

    # Return a response indicating the job was queued with CV generation ID
    {
      status: "queued",
      message: "CV generation job has been queued and will be processed in the background",
      job_id: SecureRandom.uuid,
      cv_generation_id: cv_generation.id
    }
  end

  # Generate CV based on job description and existing resume
  def generate_cv_from_resume(job_description, resume_id, options = {})
    @resume_id = resume_id
    generate_cv(job_description, options)
  end

  # Get CV generation status
  def get_cv_generation_status(generation_id)
    generation = CvGeneration.find(generation_id)

    {
      id: generation.id,
      status: generation.status,
      job_description: generation.job_description,
      generated_content: generation.generated_content,
      tokens_used: generation.tokens_used,
      created_at: generation.created_at,
      updated_at: generation.updated_at,
      metadata: generation.metadata
    }
  end

  # Get all CV generations for a user
  def get_user_cv_generations(limit = 10)
    user = User.find(@user_id)

    user.cv_generations
        .order(created_at: :desc)
        .limit(limit)
        .map do |generation|
      get_cv_generation_status(generation.id)
    end
  end

  # Get all CV generations for a resume
  def get_resume_cv_generations(limit = 10)
    return [] unless @resume_id

    CvGeneration.where(resume_id: @resume_id)
                .order(created_at: :desc)
                .limit(limit)
                .map do |generation|
      get_cv_generation_status(generation.id)
    end
  end

  # Retry failed CV generation
  def retry_cv_generation(generation_id)
    generation = CvGeneration.find(generation_id)

    return { error: "CV generation is not in failed status" } unless generation.status == "failed"

    # Reset status and retry
    generation.update!(status: "processing")

    # Re-enqueue the job
    CvGeneratorJob.perform_async(
      generation.job_description,
      generation.user_id,
      generation.resume_id,
      generation.metadata
    )

    {
      status: "retrying",
      message: "CV generation job has been re-queued",
      generation_id: generation.id
    }
  end

  # Cancel pending CV generation
  def cancel_cv_generation(generation_id)
    generation = CvGeneration.find(generation_id)

    return { error: "CV generation cannot be cancelled" } unless generation.status == "processing"

    generation.update!(status: "cancelled")

    {
      status: "cancelled",
      message: "CV generation has been cancelled",
      generation_id: generation.id
    }
  end

  # Get CV generation statistics
  def get_cv_generation_stats
    user = User.find(@user_id)

    generations = user.cv_generations

    {
      total_generations: generations.count,
      completed: generations.where(status: "completed").count,
      failed: generations.where(status: "failed").count,
      processing: generations.where(status: "processing").count,
      cancelled: generations.where(status: "cancelled").count,
      total_tokens_used: generations.sum(:tokens_used) || 0
    }
  end
end
