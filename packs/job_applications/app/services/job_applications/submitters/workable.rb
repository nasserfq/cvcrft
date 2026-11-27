module JobApplications
  module Submitters
    # Workable's hosted form (apply.workable.com/{account}/j/{code}/apply/).
    # Questions come from the form JSON the page loads. Often behind
    # Cloudflare Turnstile, which ends as a captcha fallback. Not in
    # SUBMITTERS until a tester run passes.
    class Workable < Base
      HOSTS = [ "apply.workable.com", "workable.com", "workablecdn.com" ].freeze
      TYPES = {
        "text" => "text", "string" => "text", "short_text" => "text", "paragraph" => "textarea", "free_text" => "textarea",
        "textarea" => "textarea", "long_text" => "textarea", "email" => "email", "phone" => "tel", "file" => "file",
        "boolean" => "radio", "dropdown" => "select", "number" => "number", "numeric" => "number", "decimal" => "number",
        "date" => "text", "url" => "url", "multiple" => "checkbox", "multiple_choice" => "checkbox"
      }.freeze
      CONFIRMED_TEXT = /thank you for applying|application (?:has been )?(?:submitted|received)|successfully submitted/i

      def self.questions(posting)
        account = CGI.escape(posting.employer.identifier)
        data = get_json("https://apply.workable.com/api/v1/accounts/#{account}/jobs/#{CGI.escape(posting.external_id)}/form")
        sections = data.is_a?(Hash) ? Array(data["sections"] || [ data ]) : Array(data)
        sections.flat_map do |section|
          eeo = section["name"].to_s.match?(/eeo|voluntary|diversity/i)
          Array(section["fields"]).filter_map { |field| from_api(field, eeo ? "eeo" : "main") }
        end
      end

      def self.from_api(field, section)
        type = TYPES[field["type"].to_s]
        return unless field["id"].present? && type

        type = "radio" if type == "checkbox" && field["singleOption"]
        options = if field["type"] == "boolean" then %w[Yes No]
        else Array(field["choices"] || field["options"]).map { |c| c.is_a?(Hash) ? (c["body"] || c["name"] || c["label"]) : c }
        end
        question(id: field["id"], label: field["label"], type:, required: field["required"], options:, section:)
      end
      private_class_method :from_api

      private

      def form_url
        "https://apply.workable.com/#{CGI.escape(employer.identifier)}/j/#{CGI.escape(posting.external_id)}/apply/"
      end

      def field_selector(question) = %([name="#{css(question['id'])}"], [id="#{css(question['id'])}"])
      def submit_selector = 'button[type="submit"][data-ui="apply-button"], form button[type="submit"]'

      def confirmed?(page)
        page_text(page).match?(CONFIRMED_TEXT)
      end
    end
  end
end
