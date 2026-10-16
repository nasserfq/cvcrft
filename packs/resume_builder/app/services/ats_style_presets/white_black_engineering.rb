module AtsStylePresets
  class WhiteBlackEngineering < Base
    def self.key = "white_black_engineering"
    def self.display_name = "White/Black Engineering"
    def self.description = "Dense technical resume style with compact spacing"

    def self.layout
      super.merge(
        renderer: :render_two_column_layout,
        options: {
          left_width_ratio: 0.28,
          sidebar_title: "TECH PROFILE",
          sidebar_sections: [ :contact, :skills, :languages ],
          main_sections: [ :summary, :education, :work_experience, :certifications ]
        }
      )
    end

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
