class ChangeResumeIdNullableInLinkedinImports < ActiveRecord::Migration[8.0]
  def change
    change_column_null :linkedin_imports, :resume_id, true
  end
end
