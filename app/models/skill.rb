class Skill < ApplicationRecord
  belongs_to :resume

  # Serialize skill_names as JSON array
  serialize :skill_names, coder: JSON

  # New validations for updated structure
  validates :category, presence: true
  validates :skill_names, presence: true

  # Legacy validations (keeping for backward compatibility)
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }, allow_blank: true
  validates :level, inclusion: { in: %w[beginner intermediate advanced expert] }, allow_blank: true

  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :by_level, ->(level) { where(level: level) }
  scope :technical, -> { where(category: "technical") }
  scope :soft, -> { where(category: "soft") }
  scope :languages, -> { where(category: "language") }

  # Methods
  def level_score
    case level
    when "beginner" then 1
    when "intermediate" then 2
    when "advanced" then 3
    when "expert" then 4
    else 0
    end
  end

  def display_name
    if skill_names.present?
      skill_names.join(", ")
    else
      "#{name} (#{level})"
    end
  end

  def technical?
    category == "technical"
  end

  def soft?
    category == "soft"
  end

  def language?
    category == "language"
  end
end
