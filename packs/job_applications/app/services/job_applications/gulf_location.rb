module JobApplications
  # Maps a feed's free-text location to a Gulf country code, or nil.
  module GulfLocation
    LATIN = {
      "SA" => [ "saudi", "saudi arabia", "ksa", "riyadh", "jeddah", "jiddah", "dammam", "khobar", "al khobar", "dhahran",
                "mecca", "makkah", "medina", "madinah", "tabuk", "abha", "jubail", "yanbu", "neom", "qassim", "buraidah",
                "taif", "hail", "kingdom of saudi arabia" ],
      "AE" => [ "uae", "u.a.e", "united arab emirates", "emirates", "dubai", "abu dhabi", "sharjah", "ajman" ],
      "QA" => [ "qatar", "doha" ],
      "KW" => [ "kuwait" ],
      "BH" => [ "bahrain", "manama" ],
      "OM" => [ "oman", "muscat" ]
    }.freeze

    ARABIC = {
      "SA" => %w[السعودية الرياض جدة الدمام الخبر الظهران مكة المدينة تبوك أبها الجبيل ينبع نيوم القصيم الطائف حائل],
      "AE" => %w[الإمارات دبي أبوظبي الشارقة],
      "QA" => %w[قطر الدوحة],
      "KW" => %w[الكويت],
      "BH" => %w[البحرين المنامة],
      "OM" => %w[عمان مسقط]
    }.freeze

    ISO = {
      "SA" => "SA", "SAU" => "SA", "AE" => "AE", "ARE" => "AE", "QA" => "QA", "QAT" => "QA",
      "KW" => "KW", "KWT" => "KW", "BH" => "BH", "BHR" => "BH", "OM" => "OM", "OMN" => "OM"
    }.freeze

    REMOTE = /\A\s*(remote|anywhere|عن ?بعد)?\s*\z/i

    module_function

    # The first of the strings that names a Gulf country wins.
    def country_for(*strings)
      strings.each do |string|
        code = match(utf8(string))
        return code if code
      end
      nil
    end

    # The employer's country only counts when the posting gives no place at all.
    def for_posting(location:, country: nil, fallback: nil)
      country_for(location, country) || (REMOTE.match?(location.to_s) && country.blank? ? country_for(fallback) : nil)
    end

    # Feeds are UTF-8, but a mislabelled one must not raise on the regexps below.
    def utf8(value)
      text = value.to_s
      text = text.dup.force_encoding(Encoding::UTF_8) unless text.encoding == Encoding::UTF_8
      text.scrub("")
    end

    def normalize(text)
      utf8(text).tr("أإآ", "ااا").tr("ة", "ه").delete("ـ").downcase
    end

    def match(string)
      return nil if string.strip.empty?

      iso = iso_code(string)
      return iso if iso

      latin = string.downcase
      LATIN.each do |code, words|
        return code if words.any? { |w| latin.match?(/(?<![\p{L}\p{N}])#{Regexp.escape(w)}(?![\p{L}\p{N}])/) }
      end

      arabic = normalize(string)
      ARABIC.each do |code, words|
        return code if words.any? { |w| arabic.include?(normalize(w)) }
      end
      nil
    end

    # "SA", "SAU", or an upper-case code as its own part of "Riyadh, SA".
    def iso_code(string)
      return ISO[string.strip.upcase] if ISO.key?(string.strip.upcase)

      string.split(/[\s,;\/()|-]+/).each { |part| return ISO[part] if ISO.key?(part) }
      nil
    end
  end
end
