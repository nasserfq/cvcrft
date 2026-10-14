class AddFieldsToCoachMessages < ActiveRecord::Migration[8.0]
  def change
    # Labels of the input boxes shown under an assistant question.
    add_column :coach_messages, :fields, :jsonb, null: false, default: []
  end
end
