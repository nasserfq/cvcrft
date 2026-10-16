module AtsStylePresets
  class MinimalistRealEstate < Base
    def self.key = "minimalist_real_estate"
    def self.display_name = "Minimalist Real Estate"
    def self.description = "Minimal profile-forward layout for business roles"

    def self.layout
      super.merge(
        renderer: :render_two_column_layout,
        options: {
          left_width_ratio: 0.24,
          sidebar_title: "PROFILE SNAPSHOT",
          sidebar_sections: [ :contact, :languages ],
          main_sections: [ :summary, :education, :skills, :work_experience, :certifications ]
        }
      )
    end

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
