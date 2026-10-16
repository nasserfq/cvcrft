require "test_helper"

class AtsPreviewAssetsTest < ActiveSupport::TestCase
  BUDGETS = { "-thumb" => 15.kilobytes, "-thumb@2x" => 35.kilobytes, "" => 90.kilobytes }.freeze

  AtsStylePresets::AtsStyleCatalog.styles.map(&:key).each do |key|
    BUDGETS.each do |suffix, budget|
      test "#{key}#{suffix}.webp exists and is under #{budget / 1024} KB" do
        path = Rails.public_path.join("ats_previews/#{key}#{suffix}.webp")

        assert File.exist?(path), "missing #{path}; run bin/rails ats_previews:generate"
        assert_equal "WEBP", File.binread(path, 4, 8)
        assert_operator File.size(path), :<, budget
      end
    end
  end

  test "no legacy PNG previews remain" do
    assert_empty Dir[Rails.public_path.join("ats_previews/*.png").to_s]
  end
end
