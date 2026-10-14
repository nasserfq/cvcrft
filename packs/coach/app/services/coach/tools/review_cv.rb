module Coach
  module Tools
    class ReviewCv < RubyLLM::Tool
      description "Score every CV section from 0 (missing) to 1 (strong). Call it before you finish."

      # The default name would be "coach--tools--review_cv".
      def self.tool_name = "review_cv"

      def initialize(chat)
        @chat = chat
      end

      def execute = Coach::Judge.review(@chat.draft)
    end
  end
end
