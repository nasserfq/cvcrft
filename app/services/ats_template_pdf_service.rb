require "prawn"
require "fileutils"
require "securerandom"

class AtsTemplatePdfService
  def self.default_template_key
    AtsStylePresets::AtsStyleCatalog.styles.first.key
  end

  def self.template_catalog
    AtsStylePresets::AtsStyleCatalog.catalog.map { |style| style.slice(:key, :name, :description) }
  end

  def self.normalize_template_key(template_key)
    key = template_key.to_s
    template_catalog.any? { |style| style[:key] == key } ? key : default_template_key
  end

  def self.generate_pdf(resume, data, options = {})
    template_key = normalize_template_key(options[:template] || options["template"])

    # Preserve the exact original classic output using the legacy generator.
    if template_key == "original_classic"
      return AtsPdfGenerator.generate_pdf(resume, data, template: "classic_01")
    end

    catalog = AtsStylePresets::AtsStyleCatalog.catalog
    style = catalog.find { |item| item[:key] == template_key } || catalog.first
    config = style[:config]

    filename = resume.complete_name.present? ? "#{resume.complete_name.parameterize}_resume.pdf" : "resume_#{SecureRandom.hex(6)}.pdf"
    pdf_path = Rails.root.join("tmp", "pdfs", "generated", filename)
    FileUtils.mkdir_p(File.dirname(pdf_path))

    Prawn::Document.generate(pdf_path, force_encoding: true, margin: config[:margin] || 36) do |pdf|
      pdf.font "Helvetica", enable_smart_quotes: false do
        case template_key
        when "harvard_classic"
          render_single_column_layout(pdf, resume, data, config)
        when "white_black_engineering"
          render_two_column_layout(
            pdf,
            resume,
            data,
            config,
            left_width_ratio: 0.28,
            sidebar_title: "TECH PROFILE",
            sidebar_sections: [ :contact, :skills, :languages ],
            main_sections: [ :summary, :education, :work_experience, :certifications ]
          )
        when "simple_clean_gray"
          render_profile_band_layout(pdf, resume, data, config, band_color: "6B7280")
        when "minimalist_real_estate"
          render_two_column_layout(
            pdf,
            resume,
            data,
            config,
            left_width_ratio: 0.24,
            sidebar_title: "PROFILE SNAPSHOT",
            sidebar_sections: [ :contact, :languages ],
            main_sections: [ :summary, :education, :skills, :work_experience, :certifications ]
          )
        when "two_column_corporate"
          render_two_column_layout(
            pdf,
            resume,
            data,
            config,
            left_width_ratio: 0.32,
            sidebar_title: "CORPORATE PROFILE",
            sidebar_sections: [ :contact, :languages, :skills ],
            main_sections: [ :summary, :education, :work_experience, :certifications ]
          )
        when "blue_minimal_professional"
          render_profile_band_layout(pdf, resume, data, config, band_color: "1E3A8A")
        when "black_white_corporate"
          render_corporate_layout(pdf, resume, data, config)
        when "infographic_light"
          render_infographic_layout(pdf, resume, data, config)
        when "clean_single_column"
          render_clean_layout(pdf, resume, data, config)
        when "business_admin_modern"
          render_business_admin_layout(pdf, resume, data, config)
        else
          render_single_column_layout(pdf, resume, data, config)
        end
      end
    end

    { path: pdf_path.to_s, filename: filename }
  end

  def self.render_single_column_layout(pdf, resume, data, config)
    render_header(pdf, resume, config, align: :center)
    render_main_sections(pdf, resume, data, config)
  end

  def self.render_profile_band_layout(pdf, resume, data, config, band_color:)
    pdf.fill_color band_color
    pdf.fill_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 46
    pdf.fill_color "FFFFFF"
    pdf.move_down 8
    pdf.text resume.complete_name.to_s.strip, size: (config[:name_size] || 20), style: :bold, align: :center
    pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: (config[:contact_size] || 10), align: :center
    pdf.move_down 18
    pdf.fill_color "000000"
    render_main_sections(pdf, resume, data, config)
  end

  def self.render_two_column_layout(
    pdf,
    resume,
    data,
    config,
    left_width_ratio:,
    sidebar_title:,
    sidebar_sections: [ :contact, :languages, :skills ],
    main_sections: [ :summary, :education, :work_experience, :certifications ]
  )
    render_header(pdf, resume, config, align: :left)
    pdf.move_down 8

    left_width = (pdf.bounds.width * left_width_ratio).to_i
    right_width = pdf.bounds.width - left_width - 14
    top = pdf.cursor
    left_bottom = top
    right_bottom = top

    pdf.bounding_box([ 0, top ], width: left_width) do
      render_section_title(pdf, sidebar_title, config)
      pdf.move_down 2

      if sidebar_sections.include?(:contact)
        render_section_subtitle(pdf, "Contact")
        pdf.text resume.email.to_s, size: config[:body_size] || 10
        pdf.text resume.phone_number.to_s, size: config[:body_size] || 10
        pdf.text [ resume.city, resume.country ].compact.join(", "), size: config[:body_size] || 10
        pdf.move_down 8
      end

      if sidebar_sections.include?(:languages)
        render_languages_sidebar(pdf, data, config)
        pdf.move_down 8
      end

      if sidebar_sections.include?(:skills)
        render_skills_sidebar(pdf, data, config)
      end
      left_bottom = pdf.cursor
    end

    pdf.bounding_box([ left_width + 14, top ], width: right_width) do
      if main_sections.include?(:summary)
        render_summary(pdf, resume, data, config)
      end
      if main_sections.include?(:education)
        render_education(pdf, data, config)
      end
      if main_sections.include?(:skills)
        render_skills(pdf, data, config)
      end
      right_bottom = pdf.cursor
    end

    # Continue long content full-width below the two-column header area.
    pdf.move_cursor_to([ left_bottom, right_bottom ].min - 8)
    render_work_experience(pdf, resume, config) if main_sections.include?(:work_experience)
    render_certifications(pdf, data, config) if main_sections.include?(:certifications)
  end

  def self.render_corporate_layout(pdf, resume, data, config)
    render_header(pdf, resume, config, align: :left)
    pdf.move_down 2
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    render_main_sections(pdf, resume, data, config)
  end

  def self.render_infographic_layout(pdf, resume, data, config)
    render_header(pdf, resume, config, align: :center)
    pdf.move_down 10

    # Top section summary full width, then split.
    render_summary(pdf, resume, data, config)

    split_top = pdf.cursor
    left_width = (pdf.bounds.width * 0.50).to_i
    right_width = pdf.bounds.width - left_width - 10
    left_bottom = split_top
    right_bottom = split_top

    pdf.bounding_box([ 0, split_top ], width: left_width) do
      render_education(pdf, data, config)
      render_certifications(pdf, data, config)
      left_bottom = pdf.cursor
    end

    pdf.bounding_box([ left_width + 10, split_top ], width: right_width) do
      render_skills(pdf, data, config)
      render_languages(pdf, data, config)
      right_bottom = pdf.cursor
    end

    pdf.move_cursor_to([ left_bottom, right_bottom ].min - 8)
    render_work_experience(pdf, resume, config)
  end

  def self.render_clean_layout(pdf, resume, data, config)
    render_header(pdf, resume, config, align: :center)
    render_main_sections_clean(pdf, resume, data, config)
  end

  def self.render_business_admin_layout(pdf, resume, data, config)
    render_header(pdf, resume, config, align: :center)
    render_summary(pdf, resume, data, config)

    # Executive-focused order.
    render_work_experience(pdf, resume, config)
    render_education(pdf, data, config)
    render_certifications(pdf, data, config)
    render_skills(pdf, data, config)
    render_languages(pdf, data, config)
  end

  def self.render_main_sections(pdf, resume, data, config)
    render_summary(pdf, resume, data, config)
    render_education(pdf, data, config)
    render_work_experience(pdf, resume, config)
    render_skills(pdf, data, config)
    render_certifications(pdf, data, config)
    render_languages(pdf, data, config)
  end

  def self.render_main_sections_clean(pdf, resume, data, config)
    render_summary_clean(pdf, resume, data, config)
    render_education_clean(pdf, data, config)
    render_work_experience_clean(pdf, resume, config)
    render_skills_clean(pdf, data, config)
    render_certifications_clean(pdf, data, config)
    render_languages_clean(pdf, data, config)
  end

  def self.render_header(pdf, resume, config, align:)
    pdf.text resume.complete_name.to_s.strip, size: config[:name_size] || 20, style: :bold, align: align
    pdf.text "#{resume.email} | #{resume.phone_number} | #{[ resume.city, resume.country ].compact.join(', ')}", size: config[:contact_size] || 10, align: align
    pdf.move_down(config[:header_gap] || 18)
  end

  def self.render_section_title(pdf, title, config)
    pdf.text title, size: config[:section_title_size] || 13, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down(config[:title_gap] || 8)
  end

  def self.render_section_subtitle(pdf, title)
    pdf.text title.upcase, size: 9, style: :bold
    pdf.move_down 2
  end

  def self.render_languages_sidebar(pdf, data, config)
    return if Array(data[:languages]).blank?

    render_section_subtitle(pdf, "Languages")
    Array(data[:languages]).each do |language|
      next if language[:language].to_s.strip.blank? && language[:proficiency].to_s.strip.blank?
      pdf.float { pdf.text language[:proficiency].to_s.strip, size: config[:meta_size] || 9, align: :right }
      pdf.text language[:language].to_s.strip, size: config[:body_size] || 9, style: :bold
      pdf.move_down 1
    end
  end

  def self.render_skills_sidebar(pdf, data, config)
    return if Array(data[:skills]).blank?

    render_section_subtitle(pdf, "Skills")
    Array(data[:skills]).each do |skill|
      next if skill[:category].to_s.strip.blank? && skill[:details].to_s.strip.blank?
      pdf.text "#{skill[:category]}:", size: config[:body_size] || 9, style: :bold
      pdf.indent(8) { pdf.text skill[:details].to_s.strip, size: config[:body_size] || 9 }
      pdf.move_down 2
    end
  end

  def self.render_summary(pdf, resume, data, config)
    render_section_title(pdf, "PROFESSIONAL SUMMARY", config)
    summary = ProfessionalSummaryText.normalize(
      data[:professional_summary].to_s.strip.presence ||
      resume.professional_summary_english.presence ||
      resume.professional_summary.presence
    ) || "No professional summary available"
    pdf.text summary, size: config[:body_size] || 10, leading: config[:body_leading] || 2
    pdf.move_down(config[:section_gap] || 12)
  end

  def self.render_education(pdf, data, config)
    render_section_title(pdf, "EDUCATION", config)
    Array(data[:educations]).each do |education|
      date_text = "#{education[:start_date]} - #{education[:end_date]}"
      pdf.float { pdf.text date_text, size: config[:meta_size] || 10, align: :right }
      pdf.text education[:degree].to_s.strip, size: config[:subheading_size] || 11, style: :bold
      pdf.text education[:institution].to_s.strip, size: config[:body_size] || 10
      pdf.move_down(config[:item_gap] || 4)
    end
    pdf.move_down(config[:section_gap] || 12)
  end

  def self.render_work_experience(pdf, resume, config)
    return if resume.work_experiences.blank?

    render_section_title(pdf, "WORK EXPERIENCE", config)
    sorted = Array(resume.work_experiences).sort_by { |exp| exp.is_current ? Time.current.to_i : Date.parse(exp.start_date.to_s).to_time.to_i rescue 0 }.reverse
    sorted.each do |experience|
      date_text = "#{experience.start_date} - #{experience.is_current ? 'Present' : experience.end_date}"
      pdf.float { pdf.text date_text, size: config[:meta_size] || 10, align: :right }
      pdf.text experience.job_title.to_s.strip, size: config[:subheading_size] || 11, style: :bold
      pdf.text experience.company.to_s.strip, size: config[:body_size] || 10
      pdf.move_down(config[:company_bullet_gap] || 3)
      responsibilities = normalize_responsibilities(experience.responsibilities)
      responsibilities.each do |resp|
        next if resp.blank?
        pdf.indent(config[:bullet_indent] || 6) { pdf.text "• #{resp.to_s.strip}", size: config[:body_size] || 10 }
      end
      pdf.move_down(config[:experience_gap] || 10)
    end
  end

  def self.normalize_responsibilities(raw)
    return [] if raw.blank?
    return raw if raw.is_a?(Array)

    if raw.is_a?(String)
      begin
        parsed = JSON.parse(raw)
        return Array(parsed).map(&:to_s).map(&:strip).reject(&:blank?) if parsed.is_a?(Array)
      rescue JSON::ParserError
        # Fallback to newline-split for plain text blobs.
      end

      return raw.split("\n").map(&:strip).reject(&:blank?)
    end

    Array(raw).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def self.render_skills(pdf, data, config)
    render_section_title(pdf, "SKILLS", config)
    Array(data[:skills]).each do |skill|
      next if skill[:category].to_s.strip.blank? && skill[:details].to_s.strip.blank?
      pdf.text "#{skill[:category]}:", size: config[:body_size] || 10, style: :bold
      pdf.indent(config[:details_indent] || 15) { pdf.text skill[:details].to_s.strip, size: config[:body_size] || 10 }
      pdf.move_down(config[:item_gap] || 4)
    end
    pdf.move_down(config[:section_gap] || 10)
  end

  def self.render_certifications(pdf, data, config)
    return if Array(data[:certifications]).blank?

    render_section_title(pdf, "CERTIFICATIONS", config)
    Array(data[:certifications]).each do |cert|
      name = cert[:name].to_s.strip
      org = cert[:organization].to_s.strip
      date = cert[:date].to_s.strip
      next if name.blank?

      # Keep old-style visual hierarchy: date on right, name + organization inline.
      pdf.float { pdf.text date, size: config[:meta_size] || 10, align: :right } if date.present?
      pdf.font("Helvetica-Bold") { pdf.text "#{name}  ", size: config[:body_size] || 10, inline_format: false }

      if org.present?
        pdf.move_up(config[:cert_line_up] || 11.5)
        name_width = pdf.width_of(name, size: config[:body_size] || 10) + (config[:cert_org_indent] || 25)
        pdf.indent(name_width) do
          pdf.font("Helvetica") { pdf.text org, size: config[:body_size] || 10 }
        end
      end

      pdf.move_down(config[:item_gap] || 4)
    end
    pdf.move_down(config[:section_gap] || 10)
  end

  def self.render_languages(pdf, data, config)
    return if Array(data[:languages]).blank?

    render_section_title(pdf, "LANGUAGES", config)
    Array(data[:languages]).each do |language|
      next if language[:language].to_s.strip.blank? && language[:proficiency].to_s.strip.blank?
      pdf.float { pdf.text language[:proficiency].to_s.strip, size: config[:meta_size] || 10, align: :right }
      pdf.text language[:language].to_s.strip, size: config[:body_size] || 10, style: :bold
      pdf.move_down(config[:detail_gap] || 2)
    end
  end

  # Clean/minimal rendering uses simpler headings (no horizontal rules).
  def self.render_section_title_clean(pdf, title, config)
    pdf.text title, size: (config[:section_title_size] || 13), style: :bold
    pdf.move_down(4)
  end

  def self.render_summary_clean(pdf, resume, data, config)
    render_section_title_clean(pdf, "Professional Summary", config)
    summary = ProfessionalSummaryText.normalize(
      data[:professional_summary].to_s.strip.presence ||
      resume.professional_summary_english.presence ||
      resume.professional_summary.presence
    ) || "No professional summary available"
    pdf.text summary, size: config[:body_size] || 10, leading: config[:body_leading] || 2
    pdf.move_down(10)
  end

  def self.render_education_clean(pdf, data, config)
    render_section_title_clean(pdf, "Education", config)
    Array(data[:educations]).each do |education|
      pdf.text education[:degree].to_s.strip, size: config[:subheading_size] || 11, style: :bold
      pdf.text education[:institution].to_s.strip, size: config[:body_size] || 10
      pdf.text "#{education[:start_date]} - #{education[:end_date]}", size: config[:meta_size] || 10
      pdf.move_down(6)
    end
    pdf.move_down(6)
  end

  def self.render_work_experience_clean(pdf, resume, config)
    return if resume.work_experiences.blank?
    render_section_title_clean(pdf, "Work Experience", config)
    sorted = Array(resume.work_experiences).sort_by { |exp| exp.is_current ? Time.current.to_i : Date.parse(exp.start_date.to_s).to_time.to_i rescue 0 }.reverse
    sorted.each do |experience|
      pdf.text "#{experience.job_title} - #{experience.company}", size: config[:subheading_size] || 11, style: :bold
      pdf.text "#{experience.start_date} - #{experience.is_current ? 'Present' : experience.end_date}", size: config[:meta_size] || 10
      normalize_responsibilities(experience.responsibilities).each do |resp|
        pdf.indent(8) { pdf.text "- #{resp}", size: config[:body_size] || 10 }
      end
      pdf.move_down(8)
    end
  end

  def self.render_skills_clean(pdf, data, config)
    render_section_title_clean(pdf, "Skills", config)
    Array(data[:skills]).each do |skill|
      next if skill[:category].to_s.strip.blank? && skill[:details].to_s.strip.blank?
      pdf.text "#{skill[:category]}: #{skill[:details]}", size: config[:body_size] || 10
      pdf.move_down(3)
    end
    pdf.move_down(6)
  end

  def self.render_certifications_clean(pdf, data, config)
    return if Array(data[:certifications]).blank?
    render_section_title_clean(pdf, "Certifications", config)
    Array(data[:certifications]).each do |cert|
      next if cert[:name].blank?
      line = [ cert[:name], cert[:organization] ].compact.join(" - ")
      line = "#{line} (#{cert[:date]})" if cert[:date].present?
      pdf.text line, size: config[:body_size] || 10
      pdf.move_down(3)
    end
    pdf.move_down(6)
  end

  def self.render_languages_clean(pdf, data, config)
    return if Array(data[:languages]).blank?
    render_section_title_clean(pdf, "Languages", config)
    Array(data[:languages]).each do |language|
      next if language[:language].blank?
      pdf.text [ language[:language], language[:proficiency] ].compact.join(" - "), size: config[:body_size] || 10
      pdf.move_down(2)
    end
  end
end
