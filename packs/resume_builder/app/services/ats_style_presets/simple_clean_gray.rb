module AtsStylePresets
  class SimpleCleanGray < Base
    def self.key = "simple_clean_gray"
    def self.display_name = "Simple Clean Gray"
    def self.description = "Balanced one-column layout with soft visual rhythm"

    def self.layout
      super.merge(renderer: :render_profile_band_layout, options: { band_color: "6B7280" })
    end
  end
end
