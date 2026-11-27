module JobApplications
  # The address a posting asks applicants to email, read from its description
  # (plain text: the fetchers strip HTML). The first mailto: wins; otherwise
  # the first address with an apply keyword within 80 characters of it.
  module ApplyEmail
    ADDRESS = /[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+[A-Z]{2,24}/i
    MAILTO = /mailto:\s*(#{ADDRESS.source})/i
    KEYWORDS = /\b(?:apply|applying|applications?|cvs?|resumes?|send)\b|تقديم|السيرة/i
    NEARBY = 80
    NO_REPLY = /\A(?:no-?reply|do-?not-?reply)\b/i
    IMAGE = /\.(?:png|jpe?g|gif|svg|webp|bmp|ico)\z/i
    MAX_LENGTH = 254

    module_function

    def from(description)
      text = description.to_s
      return nil if text.blank?

      text.scan(MAILTO).flatten.map { |address| address.downcase }.find { |address| usable?(address) } ||
        nearby_keyword(text)
    end

    def nearby_keyword(text)
      text.to_enum(:scan, ADDRESS).each do
        match = Regexp.last_match
        address = match[0].downcase
        next unless usable?(address)

        before = text[[ match.begin(0) - NEARBY, 0 ].max...match.begin(0)]
        after = text[match.end(0), NEARBY].to_s
        return address if before.match?(KEYWORDS) || after.match?(KEYWORDS)
      end
      nil
    end

    def usable?(address)
      address.length <= MAX_LENGTH && !address.match?(NO_REPLY) && !address.match?(IMAGE)
    end
  end
end
