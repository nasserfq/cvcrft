module AtsTemplates
  class Classic08 < Base
    def self.key = "classic_08"
    def self.name = "Classic 08"
    def self.description = "Moderate density with clear role emphasis"

    def self.config
      super.merge(
        margin: 35,
        header_gap: 18,
        title_gap: 8,
        section_gap: 14,
        item_gap: 4,
        company_bullet_gap: 3,
        bullet_block_gap: 4,
        bullet_gap: 3,
        experience_gap: 10,
        details_indent: 14,
        cert_line_up: 11.0,
        cert_org_indent: 24
      )
    end
  end
end
