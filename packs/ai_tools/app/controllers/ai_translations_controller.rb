class AiTranslationsController < ApplicationController
  before_action :authenticate_user!

  def create
    @translation = current_user.ai_translations.build(translation_params)
    if @translation.resume_id && !current_user.resumes.exists?(@translation.resume_id)
      render json: { errors: [ "Resume not found" ] }, status: :not_found
      return
    end

    if @translation.save
      # Trigger AI translation job
      AiTranslationJob.perform_later(@translation)
      render json: { status: "processing", id: @translation.id }
    else
      render json: { errors: @translation.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def status
    @translation = current_user.ai_translations.find(params[:id])
    render json: {
      status: @translation.status,
      english_text: @translation.english_text,
      quality_score: @translation.translation_quality,
      estimated_cost: @translation.estimated_cost
    }
  end

  private

  def translation_params
    params.require(:ai_translation).permit(:arabic_text, :resume_id, :ai_model)
  end
end
