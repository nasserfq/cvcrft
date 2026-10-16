module AtsStylePresets
  class TwoColumnCorporate < Base
    def self.key = "two_column_corporate"
    def self.display_name = "Two Column Corporate"
    def self.description = "Structured executive style with side-information emphasis"

    def self.layout
      super.merge(
        renderer: :render_two_column_layout,
        options: {
          left_width_ratio: 0.32,
          sidebar_title: "CORPORATE PROFILE",
          sidebar_sections: [ :contact, :languages, :skills ],
          main_sections: [ :summary, :education, :work_experience, :certifications ]
        }
      )
    end

    def self.config
      super.merge(
        margin: 34,
        section_title_size: 12,
        body_size: 9,
        details_indent: 12
      )
    end
  end
end
