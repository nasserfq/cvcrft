module AtsTemplates
  class Base
    def self.key
      raise NotImplementedError
    end

    def self.display_name
      raise NotImplementedError
    end

    def self.description
      raise NotImplementedError
    end

    def self.config
      {
        margin: 36,
        name_size: 20,
        contact_size: 10,
        section_title_size: 13,
        subheading_size: 11,
        body_size: 10,
        meta_size: 10,
        header_gap: 20,
        title_gap: 10,
        section_gap: 15,
        item_gap: 5,
        title_company_gap: 2,
        company_bullet_gap: 4,
        bullet_block_gap: 5,
        bullet_gap: 4,
        experience_gap: 12,
        details_indent: 15,
        bullet_indent: 6,
        detail_gap: 2,
        body_leading: 2,
        cert_line_up: 11.5,
        cert_org_indent: 25
      }
    end
  end
end
