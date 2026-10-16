module AtsStylePresets
  class BlackWhiteCorporate < Base
    def self.key = "black_white_corporate"
    def self.display_name = "Black/White Corporate"
    def self.description = "Formal monochrome resume style for senior roles"

    def self.layout
      super.merge(renderer: :render_corporate_layout)
    end

    def self.config
      super.merge(
        margin: 38,
        section_title_size: 14,
        header_gap: 22,
        section_gap: 16
      )
    end
  end
end
