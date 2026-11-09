module CvGenerator
  # Draws a generation's PDF from its generated data and returns the metadata
  # keys that describe it. Nothing is written: the caller stores the keys in
  # the same update as the content they were drawn from, so a failed render
  # leaves the generation's last good PDF in place.
  class PdfRenderer
    # Bump when the layout changes; stored on each generation as pdf_version.
    VERSION = "2.1"

    def initialize(resume, template_key)
      @resume = resume
      @template_key = AtsTemplatePdfService.normalize_template_key(template_key)
    end

    # generated_data: the hash stored as metadata["generated_data"] (string
    # or symbol keys). Raises when the PDF can't be drawn.
    def call(generated_data)
      data = normalize(generated_data)
      result = AtsTemplatePdfService.generate_pdf(@resume, data, template: @template_key)
      pdf = File.binread(result[:path])

      {
        "ats_template" => @template_key,
        "pdf_generated" => true,
        "pdf_filename" => result[:filename],
        "pdf_size" => pdf.bytesize,
        "pdf_data" => Base64.encode64(pdf),
        "pdf_version" => VERSION,
        "pdf_generated_at" => Time.now.to_i
      }
    end

    private

    # Responsibilities are drawn as a list, so a string (or a description
    # without them) is split into lines.
    def normalize(generated_data)
      data = generated_data.to_h.deep_symbolize_keys
      Array(data[:work_experiences]).each do |exp|
        if exp[:responsibilities].blank? && exp[:description].present?
          exp[:responsibilities] = lines(exp[:description])
        elsif exp[:responsibilities].is_a?(String)
          exp[:responsibilities] = lines(exp[:responsibilities])
        end
      end
      data
    end

    def lines(text)
      text.to_s.split("\n").map(&:strip).reject(&:blank?)
    end
  end
end
