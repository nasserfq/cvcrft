class CleanEmptySkillNames < ActiveRecord::Migration[8.0]
  def up
    # Clean up skills that have empty skill_names
    Skill.find_each do |skill|
      begin
        if skill.skill_names.present?
          # Parse skill_names if it's a string
          skill_names = if skill.skill_names.is_a?(String)
            begin
              JSON.parse(skill.skill_names)
            rescue JSON::ParserError
              []
            end
          else
            skill.skill_names
          end

          # Ensure it's an array
          skill_names = [] unless skill_names.is_a?(Array)

          # Filter out empty strings
          cleaned_names = skill_names.reject { |name| name.blank? }

          # Update the skill if there are changes
          if cleaned_names != skill_names
            skill.update_column(:skill_names, cleaned_names.to_json)
          end
        end
      rescue => e
        Rails.logger.error "Error cleaning skill #{skill.id}: #{e.message}"
        # Skip this skill and continue
      end
    end
  end

  def down
    # This migration is not reversible as it cleans data
  end
end
