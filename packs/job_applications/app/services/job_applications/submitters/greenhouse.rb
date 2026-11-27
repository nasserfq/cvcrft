module JobApplications
  module Submitters
    # Greenhouse's hosted form (job-boards.greenhouse.io). Questions come from
    # the Job Board API: https://developers.greenhouse.io/job-board.html#retrieve-a-job
    class Greenhouse < Base
      HOSTS = [
        "greenhouse.io",
        %r{\Ahttps://grnhse[a-z0-9.-]*\.s3[a-z0-9.-]*\.amazonaws\.com/}, # resume uploads
        "www.google.com/recaptcha/", "www.gstatic.com/recaptcha/", "www.recaptcha.net/recaptcha/"
      ].freeze
      TYPES = {
        "input_text" => "text", "textarea" => "textarea", "input_file" => "file",
        "multi_value_single_select" => "select", "multi_value_multi_select" => "checkbox"
      }.freeze
      SPECIAL_TYPES = { "email" => "email", "phone" => "tel" }.freeze
      CONFIRMED_TEXT = /thank you for applying/i

      def self.questions(posting)
        token = CGI.escape(posting.employer.identifier)
        data = get_json("https://boards-api.greenhouse.io/v1/boards/#{token}/jobs/#{CGI.escape(posting.external_id)}?questions=true")
        main = Array(data["questions"]) + Array(data["location_questions"])
        eeo = Array(data["compliance"]).flat_map { |group| Array(group["questions"]) }
        main.filter_map { |q| from_api(q, "main") } +
          eeo.filter_map { |q| from_api(q, "eeo") } +
          Array(data.dig("demographic_questions", "questions")).filter_map { |q| demographic(q) }
      end

      # One question can carry several fields (resume file + resume_text);
      # the file, or else the first visible field, is the one filled.
      def self.from_api(raw, section)
        fields = Array(raw["fields"]).reject { |f| f["type"] == "input_hidden" }
        field = fields.find { |f| f["type"] == "input_file" } || fields.first
        return unless field && TYPES.key?(field["type"])

        type = SPECIAL_TYPES[field["name"]] || TYPES[field["type"]]
        question(id: field["name"], label: raw["label"], type:, required: raw["required"],
                 options: Array(field["values"]).map { |v| v["label"] }, section:)
      end
      private_class_method :from_api

      def self.demographic(raw)
        type = raw["type"] == "multi_value_multi_select" ? "checkbox" : "select"
        question(id: "demographic_#{raw['id']}", label: raw["label"], type:, required: raw["required"],
                 options: Array(raw["answer_options"]).map { |o| o["label"] }, section: "eeo")
      end
      private_class_method :demographic

      private

      def form_url
        "https://job-boards.greenhouse.io/embed/job_app?for=#{CGI.escape(employer.identifier)}&token=#{CGI.escape(posting.external_id)}"
      end

      def form_selector = "form#application-form, form#application_form, form"

      # Greenhouse keys its inputs by id (first_name, question_123, resume).
      def field_selector(question) = %([id="#{css(question['id'])}"])
      def file_selector(question) = %(input[type="file"][id="#{css(question['id'])}"])
      # Its checkbox ids carry the option ("question_7[]_11"), so groups go by name.
      def field_key(field)
        return field["name"].presence || field["id"] if %w[radio checkbox].include?(field["type"])

        field["id"].presence || field["name"]
      end

      def confirmed?(page)
        page.current_url.to_s.match?(%r{/confirmation}) || page_text(page).match?(CONFIRMED_TEXT)
      end
    end
  end
end
