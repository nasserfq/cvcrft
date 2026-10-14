module Coach
  module Tools
    class AskFields < RubyLLM::Tool
      description <<~TEXT.squish
        Show input boxes under your question so the user can fill in short answers
        (names, email, phone, city, dates, job title, company). Still write the question in your reply.
      TEXT
      parameter :labels, description: 'JSON array of box labels in the user\'s language, e.g. ["Email","Phone"]. At most 6.'

      # The default name would be "coach--tools--ask_fields".
      def self.tool_name = "ask_fields"

      attr_reader :labels

      def initialize(_chat)
        @labels = []
      end

      def execute(labels:)
        list = JSON.parse(labels)
        return { error: "send a JSON array of 1 to 6 labels" } unless list.is_a?(Array) && list.size.between?(1, 6)

        @labels = list.map { |label| label.to_s.strip.first(60) }.compact_blank
        "the boxes will show under your reply"
      rescue JSON::ParserError => e
        { error: e.message }
      end
    end
  end
end
