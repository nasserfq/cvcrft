module AtsTemplates
  class Classic04 < Base
    def self.key = "classic_04"
    def self.name = "Classic 04"
    def self.description = "Strong section headers and clean body text"

    def self.config
      super.merge(
        section_title_size: 14,
        title_gap: 8,
        section_gap: 14,
        item_gap: 4,
        experience_gap: 10,
        details_indent: 14
      )
    end
  end
end
