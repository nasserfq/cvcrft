namespace :ats_previews do
  # Each variant is encoded at the highest WebP quality (stepping down by 5)
  # that fits its byte budget, so text stays as crisp as the budget allows.
  ATS_PREVIEW_VARIANTS = [
    { suffix: "-thumb", width: 320, max_quality: 75, budget: 14.kilobytes },
    { suffix: "-thumb@2x", width: 640, max_quality: 50, budget: 34.kilobytes },
    { suffix: "", width: 1000, max_quality: 65, budget: 88.kilobytes }
  ].freeze
  ATS_PREVIEW_MIN_QUALITY = 15

  desc "Render page 1 of every ATS template into public/ats_previews/<key>{-thumb,-thumb@2x,}.webp"
  task generate: :environment do
    require "vips"

    out_dir = Rails.root.join("public", "ats_previews")
    FileUtils.mkdir_p(out_dir)
    sample = AtsStylePresets::AtsPreviewSample

    AtsTemplatePdfService.template_catalog.each do |item|
      key = item[:key]
      result = AtsTemplatePdfService.generate_pdf(sample.resume, sample.data, template: key)
      # Render once at 200 dpi (1700px wide for Letter), then downscale per variant.
      master = Vips::Image.pdfload(result[:path], page: 0, dpi: 200).flatten(background: 255)

      ATS_PREVIEW_VARIANTS.each do |variant|
        target = out_dir.join("#{key}#{variant[:suffix]}.webp").to_s
        image = master.resize(variant[:width].to_f / master.width, kernel: :lanczos3)
        quality = variant[:max_quality]
        loop do
          image.webpsave(target, Q: quality, effort: 6, strip: true)
          break if File.size(target) <= variant[:budget] || quality <= ATS_PREVIEW_MIN_QUALITY

          quality -= 5
        end
        puts "#{File.basename(target)}: #{(File.size(target) / 1024.0).round(1)} KB (q#{quality})"
      end
    ensure
      File.delete(result[:path]) if result && File.exist?(result[:path])
    end
  end
end
