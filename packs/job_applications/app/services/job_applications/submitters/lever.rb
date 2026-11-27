module JobApplications
  module Submitters
    # Lever's hosted apply page (jobs.lever.co/{site}/{id}/apply). It has no
    # questions API, so the questions are read from the page's HTML. Usually
    # behind hCaptcha, which ends as a captcha fallback. Not in SUBMITTERS
    # until a tester run passes.
    class Lever < Base
      HOSTS = [ "jobs.lever.co", "lever.co" ].freeze
      INPUTS = "input:not([type=hidden]):not([type=submit]):not([type=button]), textarea, select".freeze
      REQUIRED_MARK = /[✱*]/
      CONFIRMED_TEXT = /application submitted|thanks for applying|thank you for applying/i

      def self.questions(posting)
        doc = Nokogiri::HTML(get_html(apply_url(posting)))
        form = doc.at_css("form#application-form, form") || doc
        form.css(".application-question").filter_map { |li| from_html(li) }.uniq { |q| q["id"] }
      end

      def self.apply_url(posting)
        url = posting.apply_url.to_s
        return url if URI(url).host == "jobs.lever.co" && url.end_with?("/apply")

        site = posting.employer.site.presence || posting.employer.identifier
        "https://jobs.lever.co/#{CGI.escape(site)}/#{CGI.escape(posting.external_id)}/apply"
      rescue URI::InvalidURIError
        "https://jobs.lever.co/#{CGI.escape(posting.employer.identifier)}/#{CGI.escape(posting.external_id)}/apply"
      end

      def self.from_html(node)
        inputs = node.css(INPUTS)
        input = inputs.first
        return unless input && input["name"].present?

        label_node = node.at_css(".application-label") || node.at_css("label")
        label = (label_node || node).text.gsub(REQUIRED_MARK, " ").squish
        required = node.at_css(".required").present? || inputs.any? { |i| i.key?("required") }
        question(id: input["name"], label:, type: html_type(input), required:, options: html_options(input, inputs),
                 section: input["name"].start_with?("eeo[") ? "eeo" : "main")
      end
      private_class_method :from_html

      def self.html_type(input)
        case input.name
        when "textarea" then "textarea"
        when "select" then "select"
        else
          type = input["type"].to_s.downcase
          Base::QUESTION_TYPES.include?(type) ? type : "text"
        end
      end
      private_class_method :html_type

      def self.html_options(input, inputs)
        if input.name == "select"
          input.css("option").map { |o| o.text.squish }.compact_blank.reject { |t| t.match?(/\Aselect\b/i) }
        elsif %w[radio checkbox].include?(input["type"])
          inputs.map { |i| i.parent&.name == "label" ? i.parent.text.squish : i["value"].to_s }.compact_blank
        else
          []
        end
      end
      private_class_method :html_options

      private

      def form_url = self.class.apply_url(posting)
      def form_selector = "form#application-form, form"
      def submit_selector = "#btn-submit, form button[type=\"submit\"]"

      def confirmed?(page)
        page.current_url.to_s.match?(%r{/thanks\b}) || page_text(page).match?(CONFIRMED_TEXT)
      end
    end
  end
end
