module AtsTemplates
  class Classic03 < Base
    def self.key = "classic_03"
    def self.name = "Classic 03"
    def self.description = "Airy layout with larger section gaps"

    def self.config
      super.merge(
        margin: 34,
        name_size: 21,
        header_gap: 24,
        title_gap: 12,
        section_gap: 18,
        item_gap: 6,
        title_company_gap: 3,
        company_bullet_gap: 5,
        bullet_block_gap: 6,
        bullet_gap: 5,
        experience_gap: 14,
        details_indent: 16,
        bullet_indent: 7,
        detail_gap: 3,
        body_leading: 3,
        cert_line_up: 12.0,
        cert_org_indent: 27
      )
    end
  end
end
