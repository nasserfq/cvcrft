class AddProgressToCvAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :cv_analyses, :progress, :integer, default: 0, null: false
  end
end
