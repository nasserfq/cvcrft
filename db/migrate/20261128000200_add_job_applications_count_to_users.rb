# Free-tier counter for Seera Apply sends (UserUsageLimits :job_application).
# A constant default is metadata-only on Postgres 11+, so no rewrite or long lock.
class AddJobApplicationsCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :job_applications_count, :integer, null: false, default: 0
  end
end
