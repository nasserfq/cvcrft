require "test_helper"

class ResumeBuilder::AtsStylePresetsTest < ActiveSupport::TestCase
  # Snapshot of AtsTemplatePdfService.template_catalog taken before the
  # display_name rename. The frontend reads these hashes, so they must not move.
  EXPECTED_CATALOG = [
    { key: "original_classic", name: "Original Classic (Legacy)", description: "Your previous default ATS template style" },
    { key: "harvard_classic", name: "Harvard Classic", description: "Traditional academic hierarchy with generous spacing" },
    { key: "white_black_engineering", name: "White/Black Engineering", description: "Dense technical resume style with compact spacing" },
    { key: "simple_clean_gray", name: "Simple Clean Gray", description: "Balanced one-column layout with soft visual rhythm" },
    { key: "minimalist_real_estate", name: "Minimalist Real Estate", description: "Minimal profile-forward layout for business roles" },
    { key: "two_column_corporate", name: "Two Column Corporate", description: "Structured executive style with side-information emphasis" },
    { key: "blue_minimal_professional", name: "Blue Minimal Professional", description: "Professional ATS layout inspired by blue-accent resumes" },
    { key: "black_white_corporate", name: "Black/White Corporate", description: "Formal monochrome resume style for senior roles" },
    { key: "infographic_light", name: "Infographic Light", description: "Readable modern layout with ATS-safe typography" },
    { key: "clean_single_column", name: "Clean Single Column", description: "Simple modern one-column ATS template" },
    { key: "business_admin_modern", name: "Business Admin Modern", description: "Executive summary-led style for administration profiles" }
  ].freeze

  test "every style has a String display_name" do
    AtsStylePresets::AtsStyleCatalog.styles.each do |style|
      assert_kind_of String, style.display_name, style.to_s
    end
  end

  test "style.name is the Ruby constant name" do
    assert_equal "AtsStylePresets::HarvardClassic", AtsStylePresets::HarvardClassic.name
    AtsStylePresets::AtsStyleCatalog.styles.each do |style|
      assert_match(/\AAtsStylePresets::[A-Z]\w+\z/, style.name)
    end
  end

  test "base classes keep Module#name" do
    assert_equal "AtsStylePresets::Base", AtsStylePresets::Base.name
    assert_equal "AtsTemplates::Base", AtsTemplates::Base.name
  end

  test "legacy template keeps its display label" do
    assert_equal "Classic 01", AtsTemplates::Classic01.display_name
    assert_equal "AtsTemplates::Classic01", AtsTemplates::Classic01.name
    assert_equal [ { key: "classic_01", name: "Classic 01", description: "Balanced spacing and standard headings" } ],
      AtsPdfGenerator.template_catalog
  end

  test "template_catalog is unchanged" do
    assert_equal EXPECTED_CATALOG, AtsTemplatePdfService.template_catalog
  end

  test "every layout renderer is an AtsTemplatePdfService method" do
    AtsStylePresets::AtsStyleCatalog.styles.each do |style|
      layout = style.layout
      assert_respond_to AtsTemplatePdfService, layout[:renderer], style.name
      assert_kind_of Hash, layout[:options], style.name
    end
  end

  test "only original_classic uses the legacy generator" do
    legacy = AtsStylePresets::AtsStyleCatalog.styles.select(&:legacy_template)
    assert_equal [ AtsStylePresets::OriginalClassic ], legacy
    assert_equal "classic_01", AtsStylePresets::OriginalClassic.legacy_template
  end

  test "find returns the style for a key and falls back to the first" do
    assert_equal AtsStylePresets::InfographicLight, AtsStylePresets::AtsStyleCatalog.find("infographic_light")
    assert_equal AtsStylePresets::OriginalClassic, AtsStylePresets::AtsStyleCatalog.find("nope")
  end
end
