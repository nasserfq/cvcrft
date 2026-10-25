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

    style = AtsStylePresets::AtsStyleCatalog.find(template_key)
    # Preserve the exact original classic output using the legacy generator.
    return AtsPdfGenerator.generate_pdf(resume, data, template: style.legacy_template) if style.legacy_template

    config = style.config

    filename = resume.complete_name.to_s.parameterize.presence&.then { |slug| "#{slug}_resume.pdf" } || "resume.pdf"
    pdf_path = AtsPdfGenerator.unique_pdf_path

    Prawn::Document.generate(pdf_path, force_encoding: true, margin: config[:margin] || 36) do |pdf|
      pdf.extend(PdfText::Document)
      pdf.font "Helvetica", enable_smart_quotes: false do
        layout = style.layout
        public_send(layout[:renderer], pdf, resume, data, config, **layout[:options])
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

    render_side_by_side(
      pdf,
      [ 0, left_width ],
      [ left_width + 14, right_width ],
      left: lambda {
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

        render_skills_sidebar(pdf, data, config) if sidebar_sections.include?(:skills)
      },
      # The main column carries every main section in order, so work experience
      # follows the summary directly instead of waiting below the sidebar.
      right: lambda {
        main_sections.each do |section|
          case section
          when :summary then render_summary(pdf, resume, data, config)
          when :education then render_education(pdf, data, config)
          when :skills then render_skills(pdf, data, config)
          when :work_experience then render_work_experience(pdf, resume, config)
          when :certifications then render_certifications(pdf, data, config)
          end
        end
      }
    )
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

    left_width = (pdf.bounds.width * 0.50).to_i
    right_width = pdf.bounds.width - left_width - 10

    render_side_by_side(
      pdf,
      [ 0, left_width ],
      [ left_width + 10, right_width ],
      left: lambda {
        render_education(pdf, data, config)
        render_certifications(pdf, data, config)
      },
      right: lambda {
        render_skills(pdf, data, config)
        render_languages(pdf, data, config)
      }
    )
    pdf.move_down 8
    render_work_experience(pdf, resume, config)
  end

  # Draws two columns that start at the current position, then leaves the
  # document just below whichever column ended lower (the later page, or the
  # smaller y on the same page) so following content continues without a gap.
  # Prawn's cursor inside a stretchy bounding_box is always 0, so this works
  # with absolute page numbers and y positions instead. A column that spills
  # onto the next page continues from that page's top margin.
  def self.render_side_by_side(pdf, left_column, right_column, left:, right:)
    start_page = pdf.page_number
    top = pdf.cursor
    ends = []

    [ [ left_column, left ], [ right_column, right ] ].each do |(x, width), body|
      pdf.go_to_page(start_page)
      pdf.bounding_box([ x, top ], width: width) do
        flow_from_page_top(pdf.bounds)
        body.call
      end
      ends << [ pdf.page_number, pdf.y ]
    end

    page, y = ends.max_by { |page_number, end_y| [ page_number, -end_y ] }
    pdf.go_to_page(page)
    pdf.y = y
  end

  # A Prawn bounding box keeps its original top on every page it spills onto,
  # which would leave the header's height blank at the top of page 2. Move the
  # column up to the top margin whenever it breaks onto another page.
  def self.flow_from_page_top(box)
    page_top = box.parent.absolute_top
    box.define_singleton_method(:move_past_bottom) do
      @y = page_top
      super()
    end
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
    sorted = sort_experiences_newest_first(resume.work_experiences)
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

  # Current roles first, then by start date, newest first. Roles whose start
  # date cannot be read go last; ties keep their input order.
  def self.sort_experiences_newest_first(experiences)
    oldest = Date.new(1, 1, 1)
    Array(experiences).each_with_index.sort_by do |experience, index|
      start = parse_resume_date(experience.start_date) || oldest
      [ experience.is_current ? 0 : 1, -start.jd, index ]
    end.map(&:first)
  end

  # Reads the date formats resumes carry: Date/Time objects, "YYYY-MM-DD",
  # "YYYY-MM", "YYYY", "MM/YYYY", and "Present"/"Current" (today). Returns nil
  # for blank or unreadable values.
  def self.parse_resume_date(value)
    return value.to_date if value.is_a?(Date) || value.is_a?(Time)

    text = value.to_s.strip
    return nil if text.blank?
    return Date.current if text.match?(/\A(present|current|now)\z/i)

    year, month, day =
      case text
      when /\A(\d{4})-(\d{1,2})-(\d{1,2})/ then [ $1, $2, $3 ]
      when /\A(\d{4})[-\/](\d{1,2})\z/ then [ $1, $2, 1 ]
      when /\A(\d{1,2})\/(\d{4})\z/ then [ $2, $1, 1 ]
      when /\A(\d{4})\z/ then [ $1, 1, 1 ]
      end
    return Date.new(year.to_i, month.to_i, day.to_i) if year && Date.valid_date?(year.to_i, month.to_i, day.to_i)
    return nil if year

    Date.parse(text)
  rescue Date::Error
    nil
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
    sorted = sort_experiences_newest_first(resume.work_experiences)
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
