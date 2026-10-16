module AtsStylePresets
  class BusinessAdminModern < Base
    def self.key = "business_admin_modern"
    def self.display_name = "Business Admin Modern"
    def self.description = "Executive summary-led style for administration profiles"

    def self.layout
      super.merge(renderer: :render_business_admin_layout)
    end

    def self.config
      super.merge(
        margin: 40,
        name_size: 22,
        section_title_size: 13,
        header_gap: 22
      )
    end
  end
end
