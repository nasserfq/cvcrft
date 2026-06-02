module AtsStylePresets
  class MinimalistRealEstate < Base
    def self.key = "minimalist_real_estate"
    def self.name = "Minimalist Real Estate"
    def self.description = "Minimal profile-forward layout for business roles"

    def self.config
      super.merge(
        name_size: 21,
        section_title_size: 12,
        header_gap: 18,
        section_gap: 12
      )
    end
  end
end
