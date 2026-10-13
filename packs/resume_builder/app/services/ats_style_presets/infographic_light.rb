module AtsStylePresets
  class InfographicLight < Base
    def self.key = "infographic_light"
    def self.name = "Infographic Light"
    def self.description = "Readable modern layout with ATS-safe typography"

    def self.config
      super.merge(
        margin: 33,
        body_size: 9,
        meta_size: 9,
        section_gap: 11,
        item_gap: 3
      )
    end
  end
end
