require_relative "base"
require_relative "original_classic"
require_relative "harvard_classic"
require_relative "white_black_engineering"
require_relative "simple_clean_gray"
require_relative "minimalist_real_estate"
require_relative "two_column_corporate"
require_relative "blue_minimal_professional"
require_relative "black_white_corporate"
require_relative "infographic_light"
require_relative "clean_single_column"
require_relative "business_admin_modern"

module AtsStylePresets
  module AtsStyleCatalog
    STYLES = [
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

    def self.catalog
      STYLES.map do |style|
        {
          key: style.key,
          name: style.name,
          description: style.description,
          config: style.config
        }
      end
    end
  end

  STYLES = AtsStyleCatalog::STYLES

  def self.catalog
    AtsStyleCatalog.catalog
  end
end
