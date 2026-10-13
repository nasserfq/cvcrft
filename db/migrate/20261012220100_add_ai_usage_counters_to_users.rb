# Append-only AI usage counters. Usage used to be counted from completed rows
# the user can delete, so deleting a resume gave the quota back.
class AddAiUsageCountersToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :summary_translations_count, :integer, default: 0, null: false
    add_column :users, :jobs_translations_count, :integer, default: 0, null: false
    add_column :users, :job_based_generations_count, :integer, default: 0, null: false
    add_column :users, :document_ai_count, :integer, default: 0, null: false

    # Start each counter at what the user has already used.
    execute <<~SQL
      UPDATE users SET
        summary_translations_count = (
          SELECT COUNT(*) FROM ai_translations t
          WHERE t.user_id = users.id AND t.status = 'completed'
            AND t.metadata->>'professional_summary' = 'true'),
        jobs_translations_count = (
          SELECT COUNT(*) FROM ai_translations t
          WHERE t.user_id = users.id AND t.status = 'completed'
            AND t.metadata->>'job_descriptions' = 'true'),
        job_based_generations_count = (
          SELECT COUNT(*) FROM cv_generations g
          WHERE g.user_id = users.id AND g.status = 'completed'
            AND g.metadata->>'source' = 'job_description'),
        document_ai_count =
          (SELECT COUNT(*) FROM cv_analyses a WHERE a.user_id = users.id) +
          (SELECT COUNT(*) FROM cv_imports i WHERE i.user_id = users.id) +
          (SELECT COUNT(*) FROM linkedin_imports l WHERE l.user_id = users.id)
    SQL
  end

  def down
    remove_column :users, :summary_translations_count
    remove_column :users, :jobs_translations_count
    remove_column :users, :job_based_generations_count
    remove_column :users, :document_ai_count
  end
end
