module JobApplications
  # The words of a job title that say what the job is, for the keyword prefilter.
  module TitleTokens
    STOP_WORDS = %w[
      senior junior lead principal head chief staff associate assistant intern trainee
      and the for with of in at
      أول اول كبير مساعد متدرب رئيس
    ].freeze

    module_function

    def call(title)
      GulfLocation.normalize(title).scan(/[\p{L}\p{N}+#]+/).map { |t| GulfLocation.normalize(t) }
        .reject { |t| t.size < 3 || STOP_WORDS.include?(t) || stop_words.include?(t) }.uniq
    end

    def overlap?(wanted_titles, title)
      tokens = call(title)
      wanted_titles.any? { |wanted| call(wanted).intersect?(tokens) }
    end

    def stop_words
      @stop_words ||= STOP_WORDS.map { |w| GulfLocation.normalize(w) }.to_set
    end
  end
end
