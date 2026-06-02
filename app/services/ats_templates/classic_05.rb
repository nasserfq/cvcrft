module AtsTemplates
  class Classic05 < Base
    def self.key = "classic_05"
    def self.name = "Classic 05"
    def self.description = "Minimal separators with readable hierarchy"

    def self.config
      super.merge(
        margin: 38,
        name_size: 19,
        header_gap: 16,
        section_gap: 12,
        item_gap: 4,
        company_bullet_gap: 3,
        bullet_block_gap: 4,
        bullet_gap: 3,
        experience_gap: 10,
        details_indent: 13,
        cert_line_up: 11.0,
        cert_org_indent: 23
      )
    end
  end
end
