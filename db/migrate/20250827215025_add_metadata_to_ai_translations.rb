class AddMetadataToAiTranslations < ActiveRecord::Migration[8.0]
  def up
    add_column :ai_translations, :metadata, :jsonb, default: {}
    add_index :ai_translations, :metadata, using: :gin
  end

  def down
    remove_index :ai_translations, :metadata if index_exists?(:ai_translations, :metadata)
    remove_column :ai_translations, :metadata
  end
end
