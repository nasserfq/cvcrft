module AtsStylePresets
  class BlueMinimalProfessional < Base
    def self.key = "blue_minimal_professional"
    def self.display_name = "Blue Minimal Professional"
    def self.description = "Professional ATS layout inspired by blue-accent resumes"

    def self.layout
      super.merge(renderer: :render_profile_band_layout, options: { band_color: "1E3A8A" })
    end

    def self.config
      super.merge(
        margin: 35,
        section_title_size: 13,
        header_gap: 16,
        section_gap: 14
      )
    end
  end
end
