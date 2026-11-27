module JobApplications
  module Submitters
    # Ashby's hosted form (jobs.ashbyhq.com/{org}/{id}/application). Questions
    # come from the same GraphQL call the page makes (ApiJobPosting).
    class Ashby < Base
      HOSTS = [
        "jobs.ashbyhq.com", "app.ashbyhq.com", "ashbyprd.com",
        "www.google.com/recaptcha/", "www.gstatic.com/recaptcha/", "www.recaptcha.net/recaptcha/"
      ].freeze
      GRAPHQL_URL = "https://jobs.ashbyhq.com/api/non-user-graphql?op=ApiJobPosting".freeze
      QUERY = <<~GRAPHQL.freeze
        query ApiJobPosting($organizationHostedJobsPageName: String!, $jobPostingId: String!) {
          jobPosting(organizationHostedJobsPageName: $organizationHostedJobsPageName, jobPostingId: $jobPostingId) {
            id
            title
            applicationForm {
              sections { title fieldEntries { ... on FormFieldEntry { id field isRequired } } }
            }
          }
        }
      GRAPHQL
      TYPES = {
        "String" => "text", "Email" => "email", "Phone" => "tel", "LongText" => "textarea", "File" => "file",
        "Number" => "number", "Boolean" => "radio", "ValueSelect" => "select", "MultiValueSelect" => "checkbox",
        "SocialLink" => "url", "Url" => "url", "Date" => "text", "Location" => "text"
      }.freeze
      EEO_SECTION = /eeo|voluntary|demographic|diversity/i
      SUCCESS_SELECTOR = ".ashby-application-form-success-container".freeze
      CONFIRMED_TEXT = /thank you for applying|application (?:was|has been) (?:successfully )?submitted/i

      def self.questions(posting)
        body = { operationName: "ApiJobPosting", query: QUERY,
                 variables: { organizationHostedJobsPageName: posting.employer.identifier, jobPostingId: posting.external_id } }
        sections = Array(post_json(GRAPHQL_URL, body).dig("data", "jobPosting", "applicationForm", "sections"))
        sections.flat_map do |section|
          eeo = section["title"].to_s.match?(EEO_SECTION)
          Array(section["fieldEntries"]).filter_map { |entry| from_api(entry, eeo ? "eeo" : "main") }
        end
      end

      def self.from_api(entry, section)
        field = entry["field"]
        return unless field.is_a?(Hash) && field["path"].present? && TYPES.key?(field["type"])

        required = entry.key?("isRequired") ? entry["isRequired"] : !field["isNullable"]
        options = field["type"] == "Boolean" ? %w[Yes No] : Array(field["selectableValues"]).map { |v| v["label"] }
        section = "eeo" if field["path"].to_s.include?("eeoc")
        question(id: field["path"], label: field["title"], type: TYPES[field["type"]], required:, options:, section:)
      end
      private_class_method :from_api

      private

      def form_url
        "https://jobs.ashbyhq.com/#{CGI.escape(employer.identifier)}/#{CGI.escape(posting.external_id)}/application"
      end

      def form_selector = "form, .ashby-application-form-container"
      def submit_selector = "button.ashby-application-form-submit-button, form button[type=\"submit\"]"

      def confirmed?(page)
        page.at_css(SUCCESS_SELECTOR).present? || page_text(page).match?(CONFIRMED_TEXT)
      end
    end
  end
end
