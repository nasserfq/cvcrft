module AtsTemplates
  class Classic10 < Base
    def self.key = "classic_10"
    def self.name = "Classic 10"
    def self.description = "Professional ATS style with refined spacing"

    def self.config
      super.merge(
        margin: 33,
        header_gap: 20,
        section_gap: 15
      )
    end
  end
end
