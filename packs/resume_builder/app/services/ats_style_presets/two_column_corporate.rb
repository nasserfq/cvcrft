module AtsStylePresets
  class TwoColumnCorporate < Base
    def self.key = "two_column_corporate"
    def self.name = "Two Column Corporate"
    def self.description = "Structured executive style with side-information emphasis"

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
