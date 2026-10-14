module Coach
  module Tools
    class SaveSection < RubyLLM::Tool
      description <<~TEXT.squish
        Save one finished CV section to the user's draft after they confirm it.
        Collections replace the whole list, so send every entry, not only the new one.
      TEXT
      parameter :section, description: "One of: #{Coach::Draft::SECTIONS.join(', ')}"
      parameter :json, description: <<~TEXT.squish
        The section as JSON. header: {"complete_name","email","phone_number","city","country"}.
        professional_summary: a string. work_experience: [{"job_title","company","start_date","end_date","is_current","responsibilities":[...]}].
        education: [{"degree","institution","start_date","end_date","gpa","is_current"}].
        skills: [{"category","skill_names":[...]}]. certifications: [{"name","organization","date"}].
        languages: [{"language","proficiency"}]. Dates are YYYY-MM.
      TEXT

      # The default name would be "coach--tools--save_section".
      def self.tool_name = "save_section"

      def initialize(chat)
        @chat = chat
      end

      def execute(section:, json:)
        @chat.update!(draft: Coach::Draft.merge(@chat.draft, section, JSON.parse(json)))
        Coach.broadcast(@chat, type: "draft", draft: @chat.draft)
        "saved"
      rescue Coach::Draft::Invalid, JSON::ParserError => e
        { error: e.message }
      end
    end
  end
end
