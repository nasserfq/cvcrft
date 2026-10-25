class CvGenerationService
  def initialize(user_id, resume_id = nil)
    @user_id = user_id
    @resume_id = resume_id
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
      ai_model: AiModel.default,
      status: "processing",
      metadata: json_options
    )

    # Enqueue the CV generation job
    # Add cache control option if not present
    json_options["force_pdf_regeneration"] = true unless json_options.key?("force_pdf_regeneration")

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
    generation = CvGeneration.where(user_id: @user_id).find(generation_id)

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

    CvGeneration.where(user_id: @user_id, resume_id: @resume_id)
                .order(created_at: :desc)
                .limit(limit)
                .map do |generation|
      get_cv_generation_status(generation.id)
    end
  end

  # Retry failed CV generation. The failed -> processing flip is one
  # conditional UPDATE, so of two parallel retries only one gets past it.
  # The block, if given, runs after the flip and before the job is queued
  # (the controller charges there); when it returns false the generation goes
  # back to failed and nothing is queued.
  def retry_cv_generation(generation_id)
    generation = CvGeneration.where(user_id: @user_id).find(generation_id)

    claimed = CvGeneration.where(id: generation.id, status: "failed")
                          .update_all(status: "processing", updated_at: Time.current) == 1
    return { error: "CV generation is not in failed status" } unless claimed

    begin
      if block_given? && !yield(generation)
        reset_to_failed(generation)
        return { error: "CV generation was not retried", blocked: true }
      end

      generation.reload
      CvGeneratorJob.perform_async(
        generation.job_description,
        generation.user_id,
        generation.resume_id,
        generation.metadata
      )
    rescue
      reset_to_failed(generation)
      raise
    end

    {
      status: "retrying",
      message: "CV generation job has been re-queued",
      generation_id: generation.id
    }
  end

  # Cancel pending CV generation
  def cancel_cv_generation(generation_id)
    generation = CvGeneration.where(user_id: @user_id).find(generation_id)

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

  private

  def reset_to_failed(generation)
    CvGeneration.where(id: generation.id, status: "processing").update_all(status: "failed", updated_at: Time.current)
  end
end
