module AtsStylePresets
  class CleanSingleColumn < Base
    def self.key = "clean_single_column"
    def self.display_name = "Clean Single Column"
    def self.description = "Simple modern one-column ATS template"

    def self.layout
      super.merge(renderer: :render_clean_layout)
    end
  end
end
