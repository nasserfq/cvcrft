module AtsTemplates
  class Classic07 < Base
    def self.key = "classic_07"
    def self.name = "Classic 07"
    def self.description = "Prominent name header and concise sections"

    def self.config
      super.merge(
        margin: 40,
        name_size: 22,
        subheading_size: 12,
        header_gap: 22,
        section_gap: 16
      )
    end
  end
end
