module AtsStylePresets
  class BlueMinimalProfessional < Base
    def self.key = "blue_minimal_professional"
    def self.name = "Blue Minimal Professional"
    def self.description = "Professional ATS layout inspired by blue-accent resumes"

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
