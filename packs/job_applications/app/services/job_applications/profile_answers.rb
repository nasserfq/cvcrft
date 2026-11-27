module JobApplications
  # The form answers Seera knows without asking the AI: contact details from
  # the resume header, the six setup answers on the profile, and the CV file.
  #
  #   match(question, profile:, contact:) -> value | :sensitive | nil
  #
  # :sensitive means "never ask the AI": a Sensitive question, an EEO one, or a
  # question about visas, salary and the like that the profile can't answer
  # (another country, another currency). nil means Seera doesn't know it here.
  module ProfileAnswers
    CV_FILE = "cv_pdf" # the answer for the resume upload field; the submitter attaches the PDF

    FIRST_NAME = /first\s+name|given\s+name|preferred\s+(first\s+)?name|الاسم\s+الاول/
    LAST_NAME = /last\s+name|surname|family\s+name|اسم\s+العائله|الاسم\s+الاخير|اسم\s+الاسره|اللقب/
    FULL_NAME = /\A(your\s+)?(full\s+|legal\s+)?name\z|full\s+name|legal\s+name|الاسم\s+الكامل|\Aالاسم\z/
    EMAIL = /e-?mail|البريد/
    PHONE = /phone|mobile|telephone|\bcell\b|الجوال|جوال|الهاتف|هاتف/
    LINKEDIN = /linked\s?in|لينكد/
    CITY = /\bcity\b|current\s+location|where\s+are\s+you\s+(based|located)|\Alocation\z|المدينه/
    RESIDENCE_CITY = /(مكان|محل|مدينه)\s+الاقامه/
    RESIDENCE_COUNTRY = /country\s+of\s+residen|(بلد|دوله)\s+الاقامه|\Acountry\z|\Aالدوله\z/
    RESUME = /resume|\bcv\b|curriculum|السيره\s+الذاتيه/
    COVER_LETTER = /cover\s+letter|motivation\s+letter|خطاب\s+(التقديم|تعريفي|التغطيه)|رساله\s+(التغطيه|تعريفيه)/

    NATIONALITY = /nationalit|citizenship|citizen|\bnational\b|الجنسيه|مواطن/
    SAUDI = /saudi|\bksa\b|سعودي|المملكه\s+العربيه/
    GCC = /\bgcc\b|gulf|الخليج/
    VISA = /visa|sponsor|work\s+permit|right\s+to\s+work|authori[sz]ed\s+to\s+work|eligib\w*\s+to\s+work|legally\s+(able|allowed|permitted|entitled)|iqama|residen(cy|ce)\s+permit|تاشير|كفال|اقامه|تصريح\s+(عمل|العمل)|يحق\s+لك\s+العمل/
    IQAMA = /iqama|residen(cy|ce)\s+permit|اقامه/
    SPONSORSHIP = /sponsor|require\w*\s+(a\s+)?(work\s+)?visa|need\w*\s+(a\s+)?(work\s+)?visa|كفال|رعايه/
    TRANSFERABLE = /transfer|نقل/
    AUTHORIZED = /authori[sz]ed|eligib|right\s+to\s+work|legally|permit|يحق|مصرح|تصريح/
    OTHER_COUNTRY = /
      \buae\b|emirat|dubai|abu\s+dhabi|qatar|kuwait|bahrain|oman|egypt|jordan|lebanon|
      \busa?\b|united\s+states|america|\buk\b|united\s+kingdom|britain|england|canada|europe|\beu\b|
      germany|france|ireland|netherlands|australia|india|pakistan|singapore|
      الامارات|دبي|قطر|الكويت|البحرين|عمان|مصر|الاردن|لبنان|امريكا|الولايات\s+المتحده|بريطانيا|المملكه\s+المتحده|كندا|اوروبا
    /x
    NOTICE = /notice\s+period|\bnotice\b|when\s+can\s+you\s+start|earliest\s+start|availability\s+to\s+start|available\s+to\s+start|start\s+date|فتره\s+الاشعار|مده\s+الاشعار|متي\s+يمكنك\s+البدء|تاريخ\s+البدء/
    SALARY = /salary|compensation|remuneration|pay\s+expectation|expected\s+pay|desired\s+pay|الراتب|راتب|الاجر/
    SAR = /\bsar\b|riyal|ريال|ر\.?\s?س/
    OTHER_CURRENCY = /\busd\b|\$|dollar|\baed\b|dirham|\beur\b|€|euro|\bgbp\b|£|pound|\bqar\b|\bkwd\b|دولار|درهم|يورو|جنيه/
    YEARLY = /year|annual|annum|\bpa\b|سنوي|سنه|السنه/
    MONTHLY = /month|شهري|شهر/
    OTHER_PERIOD = /hour|week|\bday\b|daily|ساعه|اسبوع|يومي/

    QUESTION_FORM = /\A(are|do|does|will|would|is|have|has|can)\b|\Aهل\b/
    YES = /\A(yes|y|true|نعم)\b/
    NO = /\A(no|n|false|لا)\b/

    NOTICE_TEXT = {
      "immediate" => "Immediately", "two_weeks" => "2 weeks", "one_month" => "1 month",
      "two_months" => "2 months", "three_months" => "3 months"
    }.freeze
    NOTICE_OPTIONS = {
      "immediate" => /immediate|right\s+away|\Anow\b|\A0\b|no\s+notice|فوري|حالا/,
      "two_weeks" => /\A(2|two)\s+weeks?|14\s+days|اسبوعين/,
      "one_month" => /\A(1|one)\s+month|\A30\s+days|\A(4|four)\s+weeks|\Aشهر\z|شهر\s+واحد/,
      "two_months" => /\A(2|two)\s+months|60\s+days|شهرين/,
      "three_months" => /\A(3|three)\s+months|90\s+days|ثلاثه\s+اشهر/
    }.freeze
    VISA_TEXT = {
      "saudi_citizen" => "Saudi citizen", "gcc_citizen" => "GCC citizen",
      "iqama_transferable" => "Iqama holder (transferable)", "iqama_not_transferable" => "Iqama holder (not transferable)",
      "needs_sponsorship" => "Requires visa sponsorship"
    }.freeze

    module_function

    def match(question, profile:, contact:)
      label = Sensitive.normalize(question["label"])
      return :sensitive if question["section"] == "eeo" || Sensitive.match?(label)
      return file_answer(label) if question["type"] == "file"

      topic_answer(question, label, profile, contact.to_h)
    end

    # True for questions this module owns (visa, salary, names...), answered or
    # not. The Answerer never sends these to the AI.
    def topic?(question)
      label = Sensitive.normalize(question["label"])
      [ NATIONALITY, VISA, SALARY, NOTICE, PHONE, LINKEDIN, EMAIL, FIRST_NAME, LAST_NAME, FULL_NAME ].any? { |re| label.match?(re) }
    end

    def cover_letter?(question) = Sensitive.normalize(question["label"]).match?(COVER_LETTER)

    def file_answer(label)
      return nil if label.match?(COVER_LETTER)

      label.match?(RESUME) ? CV_FILE : :sensitive
    end

    def topic_answer(question, label, profile, contact)
      choice = Array(question["options"]).any?
      if label.match?(RESIDENCE_CITY) then text(question, contact["city"])
      elsif label.match?(RESIDENCE_COUNTRY) then text(question, contact["country"])
      elsif label.match?(SALARY) then salary(question, label, profile)
      elsif label.match?(VISA) then visa(question, label, profile)
      elsif label.match?(NATIONALITY) then nationality(question, label, profile)
      elsif label.match?(NOTICE) then notice(question, profile)
      elsif label.match?(LINKEDIN) then text(question, profile.linkedin_url)
      elsif choice then nil
      elsif label.match?(FIRST_NAME) then name_parts(contact).first
      elsif label.match?(LAST_NAME) then name_parts(contact).drop(1).join(" ").presence
      elsif label.match?(FULL_NAME) then contact["complete_name"].to_s.squish.presence
      elsif label.match?(EMAIL) || question["type"] == "email" then contact["email"].presence
      elsif label.match?(PHONE) || question["type"] == "tel" then profile.phone.presence
      elsif label.match?(CITY) then contact["city"].presence
      end
    end

    def name_parts(contact) = contact["complete_name"].to_s.squish.split

    def nationality(question, label, profile)
      if yes_no?(question, label)
        if label.match?(SAUDI) then return yes_no(question, profile.saudi?)
        elsif label.match?(GCC) then return yes_no(question, %w[saudi_citizen gcc_citizen].include?(profile.visa_status))
        end
        return :sensitive
      end
      text(question, profile.nationality)
    end

    # Only for Saudi Arabia (or no country named): another country's visa is the user's call.
    def visa(question, label, profile)
      return :sensitive if label.match?(OTHER_COUNTRY) && !label.match?(SAUDI) && !label.match?(IQAMA)

      status = profile.visa_status
      return text(question, VISA_TEXT[status]) unless yes_no?(question, label)

      answer =
        if label.match?(IQAMA) && label.match?(TRANSFERABLE)
          { "iqama_transferable" => true, "iqama_not_transferable" => false }[status]
        elsif label.match?(SPONSORSHIP)
          { "saudi_citizen" => false, "gcc_citizen" => false, "iqama_not_transferable" => true, "needs_sponsorship" => true }[status]
        elsif label.match?(IQAMA)
          { "saudi_citizen" => false, "gcc_citizen" => false, "iqama_transferable" => true,
            "iqama_not_transferable" => true, "needs_sponsorship" => false }[status]
        elsif label.match?(AUTHORIZED)
          { "saudi_citizen" => true, "gcc_citizen" => true, "iqama_transferable" => true,
            "iqama_not_transferable" => false, "needs_sponsorship" => false }[status]
        end
      answer.nil? ? :sensitive : yes_no(question, answer)
    end

    def notice(question, profile)
      period = profile.notice_period
      return :sensitive unless NOTICE_TEXT.key?(period)
      return NOTICE_TEXT[period] if Array(question["options"]).empty?

      option = question["options"].find { |o| Sensitive.normalize(o).match?(NOTICE_OPTIONS[period]) }
      option || :sensitive
    end

    # SAR (or no currency named), per month or per year. Anything else waits for the user.
    def salary(question, label, profile)
      monthly = profile.expected_salary_sar
      return :sensitive if monthly.blank? || Array(question["options"]).any?
      return :sensitive if label.match?(OTHER_CURRENCY) && !label.match?(SAR)
      return :sensitive if label.match?(OTHER_PERIOD) && !label.match?(MONTHLY) && !label.match?(YEARLY)

      yearly = label.match?(YEARLY) && !label.match?(MONTHLY)
      (yearly ? monthly * 12 : monthly).to_s
    end

    # The value itself, or the option that spells it, for a choice question.
    def text(question, value)
      return nil if value.blank?

      options = Array(question["options"])
      return value.to_s if options.empty?

      wanted = Sensitive.normalize(value)
      options.find { |o| Sensitive.normalize(o) == wanted } || :sensitive
    end

    # Yes/no options, or a free-text question asked as "Are you...?" / "هل...؟".
    def yes_no?(question, label)
      options = Array(question["options"]).map { |o| Sensitive.normalize(o) }
      return %w[text textarea].include?(question["type"]) && label.match?(QUESTION_FORM) if options.empty?

      options.any? { |o| o.match?(YES) } && options.any? { |o| o.match?(NO) }
    end

    def yes_no(question, yes)
      options = Array(question["options"])
      return yes ? "Yes" : "No" if options.empty?

      options.find { |o| Sensitive.normalize(o).match?(yes ? YES : NO) } || :sensitive
    end
  end
end
