module AtsStylePresets
  class WhiteBlackEngineering < Base
    def self.key = "white_black_engineering"
    def self.name = "White/Black Engineering"
    def self.description = "Dense technical resume style with compact spacing"

    def self.config
      super.merge(
        margin: 32,
        name_size: 19,
        section_title_size: 12,
        body_size: 9,
        meta_size: 9,
        header_gap: 14,
        section_gap: 10,
        item_gap: 3
      )
    end
  end
end
