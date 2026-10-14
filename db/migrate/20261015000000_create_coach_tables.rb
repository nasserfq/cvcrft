class CreateCoachTables < ActiveRecord::Migration[8.0]
  def change
    create_table :coach_chats do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :path, null: false
      t.jsonb :draft, null: false, default: {}
      t.timestamps
    end

    create_table :coach_messages do |t|
      t.references :coach_chat, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :coach_messages, [ :coach_chat_id, :created_at ]
  end
end
