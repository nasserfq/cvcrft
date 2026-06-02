module AtsTemplates
  class Classic06 < Base
    def self.key = "classic_06"
    def self.name = "Classic 06"
    def self.description = "Dense ATS layout for long resumes"

    def self.config
      super.merge(
        margin: 28,
        name_size: 18,
        contact_size: 9,
        section_title_size: 12,
        subheading_size: 10,
        body_size: 9,
        meta_size: 9,
        header_gap: 12,
        title_gap: 6,
        section_gap: 10,
        item_gap: 3,
        title_company_gap: 1,
        company_bullet_gap: 2,
        bullet_block_gap: 3,
        bullet_gap: 2,
        experience_gap: 8,
        details_indent: 12,
        bullet_indent: 5,
        detail_gap: 1,
        body_leading: 1,
        cert_line_up: 10.0,
        cert_org_indent: 20
      )
    end
  end
end
