class UpdateAiTranslationsTable < ActiveRecord::Migration[8.0]
  def change
    # Make resume_id nullable since it's optional in the model
    change_column_null :ai_translations, :resume_id, true

    # Add default value for ai_model
    change_column_default :ai_translations, :ai_model, 'gpt-4.1-mini'

    # Add default value for status
    change_column_default :ai_translations, :status, 'pending'
  end
end
