module AtsStylePresets
  module AtsStyleCatalog
    def self.styles
      @styles ||= [
        OriginalClassic,
        HarvardClassic,
        WhiteBlackEngineering,
        SimpleCleanGray,
        MinimalistRealEstate,
        TwoColumnCorporate,
        BlueMinimalProfessional,
        BlackWhiteCorporate,
        InfographicLight,
        CleanSingleColumn,
        BusinessAdminModern
      ].freeze
    end

    def self.catalog
      styles.map do |style|
        {
          key: style.key,
          name: style.name,
          description: style.description,
          config: style.config
        }
      end
    end
  end
end
