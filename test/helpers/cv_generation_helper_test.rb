require "test_helper"

class CvGenerationHelperTest < ActionView::TestCase
  VERSIONED = %r{\?v=\h{8}\z}

  teardown { ENV.delete("ATS_PREVIEW_CDN_HOST") }

  test "each ATS template option carries versioned relative preview URLs" do
    options = ats_template_options_for_cv_generation

    assert_equal AtsStylePresets::AtsStyleCatalog.styles.size, options.size
    options.each do |option|
      key = option[:key]
      assert_match %r{\A/ats_previews/#{key}-thumb\.webp#{VERSIONED}}, option[:thumb_url]
      assert_match %r{\A/ats_previews/#{key}-thumb@2x\.webp#{VERSIONED}}, option[:thumb_2x_url]
      assert_match %r{\A/ats_previews/#{key}\.webp#{VERSIONED}}, option[:full_url]
      assert_equal option[:full_url], option[:preview_url]
    end
  end

  test "version is the short SHA-256 of the file content" do
    key = ats_template_options_for_cv_generation.first[:key]
    digest = Digest::SHA256.file(Rails.public_path.join("ats_previews/#{key}-thumb.webp")).hexdigest.first(8)

    assert_equal "/ats_previews/#{key}-thumb.webp?v=#{digest}", ats_template_options_for_cv_generation.first[:thumb_url]
  end

  test "prefixes the CDN host and strips its trailing slash" do
    ENV["ATS_PREVIEW_CDN_HOST"] = "https://cdn.example.com/"

    option = ats_template_options_for_cv_generation.first
    assert_match %r{\Ahttps://cdn\.example\.com/ats_previews/#{option[:key]}-thumb\.webp#{VERSIONED}}, option[:thumb_url]
    assert_match %r{\Ahttps://cdn\.example\.com/ats_previews/#{option[:key]}\.webp#{VERSIONED}}, option[:full_url]
  end

  test "blank CDN host falls back to relative paths" do
    ENV["ATS_PREVIEW_CDN_HOST"] = "  "

    assert_match %r{\A/ats_previews/}, ats_template_options_for_cv_generation.first[:thumb_url]
  end

  test "missing file yields an unversioned URL" do
    assert_equal "/ats_previews/nope.webp", CvGenerationHelper.ats_preview_url("nope.webp")
  end
end
