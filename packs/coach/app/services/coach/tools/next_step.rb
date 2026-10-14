module Coach
  module Tools
    class NextStep < RubyLLM::Tool
      description "Ask which CV section to work on next. Call it when you are unsure what to ask the user about."

      # The default name would be "coach--tools--next_step".
      def self.tool_name = "next_step"

      def initialize(chat)
        @chat = chat
      end

      def execute = Coach::Judge.next_step(@chat.draft)
    end
  end
end
