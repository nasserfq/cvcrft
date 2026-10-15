module Coach
  module Tools
    class ProposeRewrite < RubyLLM::Tool
      description <<~TEXT.squish
        Suggest one rewrite of the user's CV. The user sees the before and after and accepts or rejects it,
        so do not change the draft any other way. Propose one rewrite at a time.
      TEXT
      parameter :section, description: "professional_summary or work_experience"
      parameter :index, type: "integer", required: false,
                        description: "For work_experience: the entry's position in the draft's list, starting at 0"
      parameter :after, description: <<~TEXT.squish
        The new text, in English. professional_summary: the whole summary. work_experience: the entry's responsibilities, one per line.
      TEXT

      # The default name would be "coach--tools--propose_rewrite".
      def self.tool_name = "propose_rewrite"

      def initialize(chat)
        @chat = chat
      end

      def execute(section:, after:, index: nil)
        field = Coach::Draft::REWRITABLE[section]
        index = field && Integer(index, exception: false)
        value = field ? after.to_s.lines.map(&:strip).compact_blank : after
        proposal = nil
        # Locked and reloaded: the user may accept or reject another proposal while this turn runs.
        @chat.with_lock do
          Coach::Draft.rewrite(@chat.draft, section, index, value) # raises if the target or value is wrong
          proposal = { "id" => SecureRandom.hex(4), "section" => section, "index" => index,
                       "field" => field || section,
                       "before" => Coach::Draft.rewritable(@chat.draft, section, index), "after" => value }
          @chat.update!(proposals: @chat.proposals + [ proposal ])
        end
        Coach.broadcast(@chat, type: "proposal", proposal:)
        "proposed; wait for the user to accept or reject it"
      rescue Coach::Draft::Invalid => e
        { error: e.message }
      end
    end
  end
end
