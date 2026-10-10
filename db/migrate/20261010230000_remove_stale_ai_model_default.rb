class RemoveStaleAiModelDefault < ActiveRecord::Migration[8.0]
  # The column defaulted to "gpt-4.1-mini", which is no longer the model in
  # use and silently mislabelled any record created without an explicit value.
  # It also made `validates :ai_model, presence: true` unreachable.
  def up
    change_column_default :ai_translations, :ai_model, from: "gpt-4.1-mini", to: nil
  end

  def down
    change_column_default :ai_translations, :ai_model, from: nil, to: "gpt-4.1-mini"
  end
end
