require "digest"

module CvGenerationHelper
  ATS_PREVIEW_DIR = "ats_previews".freeze
  ATS_PREVIEW_VARIANTS = { thumb_url: "-thumb", thumb_2x_url: "-thumb@2x", full_url: "" }.freeze

  # Content hashes of the preview files, read once per process. The files are
  # static and not digested, so the hash busts CDN/browser caches on regeneration.
  def self.ats_preview_versions
    @ats_preview_versions ||= Dir[Rails.public_path.join(ATS_PREVIEW_DIR, "*.webp").to_s].to_h do |path|
      [ File.basename(path), Digest::SHA256.file(path).hexdigest.first(8) ].freeze
    end.freeze
  end

  def self.ats_preview_url(filename)
    host = ENV["ATS_PREVIEW_CDN_HOST"].to_s.strip.chomp("/")
    version = ats_preview_versions[filename]
    url = "#{host}/#{ATS_PREVIEW_DIR}/#{filename}"
    version ? "#{url}?v=#{version}" : url
  end

  def ats_template_options_for_cv_generation
    AtsTemplatePdfService.template_catalog.map do |item|
      key = item[:key]
      urls = ATS_PREVIEW_VARIANTS.transform_values { |suffix| CvGenerationHelper.ats_preview_url("#{key}#{suffix}.webp") }
      {
        key: key,
        name: t("cv_generation.ats.#{key}.name", default: item[:name]),
        description: t("cv_generation.ats.#{key}.description", default: item[:description]),
        preview_url: urls[:full_url],
        **urls
      }
    end
  end
end
