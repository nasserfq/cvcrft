module JobApplications
  # Questions only the user answers: equal-opportunity and demographic
  # questions, criminal record, and consent or legal statements. They never
  # reach the AI and are never remembered. A required one waits for the user;
  # an optional one is left blank.
  module Sensitive
    ENGLISH = /
      \beeo\b|equal\s+(employment|opportunit)|demographic|self[\s-]?identif|
      gender|\bsex\b|sexual|pronoun|transgender|lgbt|
      \brace\b|racial|ethnic|hispanic|latin[oax]|
      religio|\bfaith\b|
      disabilit|disabled|handicap|impairment|
      veteran|military\s+status|
      criminal|convict|felon|arrest|offen[cs]e|
      marital|married|pregnan|date\s+of\s+birth|\bage\b|how\s+old|
      consent|\bagree|acknowledg|\bcertify|\bdeclare|attest|
      \bterms\b|privacy|gdpr|signature|true\s+and\s+(accurate|correct|complete)
    /x
    # Matched against Sensitive.normalize(label): alef forms folded, ة as ه, no diacritics.
    ARABIC = /
      الجنس(?!يه)|النوع\s+الاجتماعي|العرق|عرقي|الديانه|الدين|المذهب|
      اعاقه|الاعاقه|ذوي\s+الاحتياجات|محارب|
      سوابق|جنائي|جريمه|ادانه|
      الحاله\s+الاجتماعيه|متزوج|تاريخ\s+الميلاد|العمر|
      موافق|اوافق|الموافقه|الشروط|الاحكام|الخصوصيه|اقر\b|اقرار|اتعهد|تعهد
    /x

    module_function

    def match?(label)
      text = normalize(label)
      text.match?(ENGLISH) || text.match?(ARABIC)
    end

    # Lowercase, NFKC, Arabic letter forms folded and diacritics dropped, so
    # one pattern covers the spellings forms use.
    def normalize(label)
      label.to_s.unicode_normalize(:nfkc).downcase
        .gsub(/[ً-ْـ]/, "").tr("أإآ", "ااا").tr("ةى", "هي").squish
    end
  end
end
