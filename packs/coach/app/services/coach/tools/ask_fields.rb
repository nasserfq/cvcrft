module Coach
  module Tools
    class AskFields < RubyLLM::Tool
      TYPES = %w[text email tel city country date_range].freeze

      description <<~TEXT.squish
        Show input boxes under your question so the user can fill in short answers.
        Still write the question in your reply.
      TEXT
      parameter :fields, description: <<~TEXT.squish
        JSON array of up to 6 boxes, each {"label","type"}. label is in the user's language and says
        "(in English)" for anything the CV prints. type is one of: #{TYPES.join(', ')}.
        city and country autocomplete; date_range is a start and end month with a "present" option, for one job or degree.
        Example: [{"label":"City (in English)","type":"city"},{"label":"Country (in English)","type":"country"}]
      TEXT

      # The default name would be "coach--tools--ask_fields".
      def self.tool_name = "ask_fields"

      attr_reader :fields

      def initialize(_chat)
        @fields = []
      end

      def execute(fields:)
        list = JSON.parse(fields)
        return { error: "send a JSON array of 1 to 6 boxes" } unless list.is_a?(Array) && list.size.between?(1, 6)

        @fields = list.filter_map do |field|
          field = { "label" => field } unless field.is_a?(Hash)
          label = field["label"].to_s.strip.first(60)
          { "label" => label, "type" => TYPES.include?(field["type"]) ? field["type"] : "text" } if label.present?
        end
        "the boxes will show under your reply"
      rescue JSON::ParserError => e
        { error: e.message }
      end
    end
  end
end
