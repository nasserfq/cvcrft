class Skill < ApplicationRecord
  belongs_to :resume

  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :level, inclusion: { in: %w[beginner intermediate advanced expert] }
  validates :category, presence: true, inclusion: { in: %w[technical soft language framework tool methodology] }

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
    "#{name} (#{level})"
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
