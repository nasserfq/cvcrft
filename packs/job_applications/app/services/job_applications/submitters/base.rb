require "net/http"

module JobApplications
  module Submitters
    # Fills and submits one ATS application form in a headless browser.
    #
    # The questions were read over HTTP (.questions) and answered while the
    # pack was built, so this only fills fields it already knows. A required
    # field on the page that has no answer stops the run before Submit.
    #
    # Subclasses set HOSTS and implement .questions(posting), #form_url,
    # #field_selector(question), #confirmed?(page), and may override #fill,
    # #file_selector, #submit_selector and #field_key.
    class Base
      HOSTS = [].freeze
      USER_AGENT = "SeeraJobs/1.0 (+https://cvcrft.com)".freeze
      QUESTION_TYPES = %w[text textarea select radio checkbox file email tel url number].freeze
      CV_ANSWER = "cv_pdf" # PackBuilder's answer for the resume file field
      FORM_WAIT = 20       # seconds for the form to appear
      CONFIRM_WAIT = 45    # seconds for the confirmation after Submit
      POLL = 0.5
      CAPTCHA_MARKERS = %w[hcaptcha.com google.com/recaptcha/api2/bframe challenges.cloudflare.com].freeze
      # Failures that leave the browser unusable. Before the click they are
      # retried (Retryable); after it they are left to the Sender.
      BROWSER_ERRORS = [ Ferrum::TimeoutError, Ferrum::DeadBrowserError, Ferrum::ProcessTimeoutError,
                         Ferrum::NoWebSocketUrlError, Ferrum::StatusError, Timeout::Error ].freeze
      # Errors while a page is navigating; the next poll tries again.
      NAVIGATING_ERRORS = [ Ferrum::BrowserError, Ferrum::NodeNotFoundError, Ferrum::NoExecutionContextError ].freeze
      CV_LABEL = /resume|\bcv\b|curriculum|السيرة/i
      COVER_LABEL = /cover/i

      # Required inputs on the page: [{"id", "name", "type"}].
      REQUIRED_FIELDS_JS = <<~JS.freeze
        Array.from(document.querySelectorAll("input, textarea, select"))
          .filter((el) => (el.required || el.getAttribute("aria-required") === "true") && el.type !== "hidden" && !el.disabled)
          .map((el) => ({ id: el.id || "", name: el.getAttribute("name") || "", type: el.type || el.tagName.toLowerCase() }))
      JS
      # True when a captcha frame is on screen (invisible reCAPTCHA keeps its frame off screen).
      CAPTCHA_JS = <<~JS.freeze
        Array.from(document.querySelectorAll("iframe")).some((frame) => {
          const src = frame.src || "";
          if (!markers.some((marker) => src.includes(marker))) return false;
          const rect = frame.getBoundingClientRect();
          const style = getComputedStyle(frame);
          return rect.width > 30 && rect.height > 30 && rect.bottom > 0 && rect.right > 0 &&
            style.visibility !== "hidden" && style.display !== "none" && style.opacity !== "0";
        })
      JS
      TEXT_JS = 'document.body ? document.body.innerText : ""'.freeze
      # Sets a text field the way typing does, so React-controlled inputs keep the value.
      SET_VALUE_JS = <<~JS.freeze
        const proto = this instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
        Object.getOwnPropertyDescriptor(proto, "value").set.call(this, value);
        this.dispatchEvent(new Event("input", { bubbles: true }));
        this.dispatchEvent(new Event("change", { bubbles: true }));
        this.dispatchEvent(new Event("blur", { bubbles: true }));
      JS
      # Ticks the radios or checkboxes named `key` (or `key[]`, or with id
      # `key` or `key[...]`) whose label is one of `labels`. Returns how many matched.
      CHECK_JS = <<~JS.freeze
        (() => {
          const wanted = labels.map((label) => String(label).trim().toLowerCase());
          const inputs = Array.from(document.querySelectorAll("input[type=radio], input[type=checkbox]"))
            .filter((el) => [key, `${key}[]`].includes(el.getAttribute("name")) || el.id === key || el.id.startsWith(`${key}[`));
          let matched = 0;
          for (const el of inputs) {
            const label = el.labels && el.labels[0] ? el.labels[0].innerText : (el.closest("label") ? el.closest("label").innerText : "");
            const names = [label, el.value].map((text) => String(text || "").trim().toLowerCase());
            if (!names.some((name) => wanted.includes(name))) continue;
            matched += 1;
            if (!el.checked) el.click();
          }
          return matched;
        })()
      JS

      class QuestionsError < StandardError; end

      class << self
        def allowlist = Browser.allowlist(self::HOSTS)

        # [Question hash] for the posting; see Submitters.
        def questions(_posting)
          raise NotImplementedError
        end

        private

        def get_json(url) = parse_json(request(Net::HTTP::Get.new(URI(url)), accept: "application/json"), url)
        def get_html(url) = request(Net::HTTP::Get.new(URI(url)), accept: "text/html")

        def post_json(url, body)
          req = Net::HTTP::Post.new(URI(url))
          req["Content-Type"] = "application/json"
          req.body = body.to_json
          parse_json(request(req, accept: "application/json"), url)
        end

        def request(req, accept:)
          uri = req.uri
          req["Accept"] = accept
          req["User-Agent"] = USER_AGENT
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 20) do |http|
            http.request(req)
          end
          raise QuestionsError, "#{uri.host}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.body.to_s
        end

        def parse_json(body, url)
          JSON.parse(body)
        rescue JSON::ParserError => e
          raise QuestionsError, "#{URI(url).host}: bad JSON (#{e.message.first(80)})"
        end

        def question(id:, label:, type:, required:, options: [], section: "main")
          { "id" => id.to_s, "label" => label.to_s.squish, "type" => type, "options" => Array(options).map(&:to_s).compact_blank,
            "required" => required ? true : false, "section" => section }
        end
      end

      attr_reader :application

      def initialize(application, cv_pdf:)
        @application = application
        @cv_pdf = cv_pdf
      end

      def call
        Dir.mktmpdir("seera-apply-files-") do |dir|
          @files_dir = dir
          browser.open(allow: allowlist) { |page| submit(page) }
        end
      rescue *BROWSER_ERRORS => e
        raise if clicked?

        raise Retryable, "#{e.class}: #{e.message.to_s.first(200)}"
      end

      def allowlist = self.class.allowlist
      def browser = Browser

      private

      def posting = application.posting
      def employer = posting.employer
      def questions = Array(application.questions)
      def answers = application.answers.to_h
      def clicked? = application.submit_clicked_at.present?

      def submit(page)
        page.go_to(form_url)
        return fallback(captcha?(page) ? "captcha" : "no_form") unless wait_for(form_wait) { page.at_css(form_selector) }
        return fallback("captcha") if captcha?(page)
        return fallback("unknown_field") if unknown_required(page).any?
        return fallback("unknown_field") if fill_form(page).any?

        return Result.fallback("dry_run", **proof(page)) if JobApplications.dry_run?

        button = page.at_css(submit_selector)
        return fallback("no_form") unless button
        raise Retryable, "application #{application.id} is no longer sending" unless application.mark_submit_clicked!

        button.click
        wait_for_outcome(page)
      end

      # Required page fields that have no answer and aren't the CV.
      def unknown_required(page)
        present = Array(page.evaluate(REQUIRED_FIELDS_JS)).filter_map { |field| normalize_key(field_key(field)) }.uniq
        present - known_keys
      end

      def known_keys
        questions.filter_map do |q|
          normalize_key(q["id"]) if answers[q["id"].to_s].present? || cv_field?(q)
        end
      end

      # Fills every answered question. Returns the ids of required questions
      # whose field wasn't found (the page changed since the questions were read).
      def fill_form(page)
        questions.filter_map do |q|
          value = q["type"] == "file" ? file_for(q) : answers[q["id"].to_s]
          next if value.blank?

          filled = q["type"] == "file" ? attach(page, q, value) : fill(page, q, value)
          q["id"] if !filled && q["required"]
        end
      end

      def fill(page, question, value)
        case question["type"]
        when "select" then choose(page, question, Array(value).first.to_s)
        when "radio", "checkbox" then check(page, question, Array(value))
        else type_text(page, question, value.to_s)
        end
      end

      def type_text(page, question, text)
        node = page.at_css(field_selector(question))
        return false unless node

        node.execute(SET_VALUE_JS, value: text)
        true
      end

      # A native <select>, or a combobox: click, type, Enter.
      def choose(page, question, option)
        node = page.at_css(field_selector(question))
        return false unless node

        if node.tag_name == "select"
          node.select(option, by: :text)
        elsif %w[radio checkbox].include?(node.attribute("type"))
          return check(page, question, [ option ])
        else
          node.click
          node.type(option, :enter)
        end
        true
      end

      def check(page, question, options)
        page.evaluate(CHECK_JS, key: field_key_for(question), labels: options.map(&:to_s)).to_i.positive?
      end

      def attach(page, question, path)
        node = page.at_css(file_selector(question))
        return false unless node

        node.select_file(path)
        true
      end

      # The tempfile path for a file question: the CV, or a required cover letter as text.
      def file_for(question)
        answer = answers[question["id"].to_s]
        return write_file(cv_filename, @cv_pdf) if cv_field?(question)
        return nil unless answer.is_a?(String) && answer.present?

        write_file("Cover letter.txt", answer)
      end

      def cv_field?(question)
        return false unless question["type"] == "file"

        answer = answers[question["id"].to_s]
        answer == CV_ANSWER || (answer.blank? && question["label"].to_s.match?(CV_LABEL) && !question["label"].to_s.match?(COVER_LABEL))
      end

      # The name the employer sees: the stored PDF's, without path or odd characters.
      def cv_filename
        name = File.basename(application.cv_pdf&.filename.to_s).gsub(/[^\p{L}\p{N} ._-]/, "").squish
        name.end_with?(".pdf") && name.delete_suffix(".pdf").present? ? name : "CV.pdf"
      end

      def write_file(name, data)
        path = File.join(@files_dir, name)
        File.binwrite(path, data)
        path
      end

      def wait_for_outcome(page)
        outcome = wait_for(confirm_wait) do
          if confirmed?(page) then :sent
          elsif captcha?(page) then :captcha
          end
        end
        case outcome
        when :sent then Result.sent(**proof(page), text: page_text(page).squish.first(500))
        when :captcha then fallback("captcha")
        else fallback("timeout")
        end
      end

      # Polls the block until it returns something truthy, or nil after `seconds`.
      def wait_for(seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        loop do
          value = begin
            yield
          rescue *NAVIGATING_ERRORS
            nil
          end
          return value if value
          return nil if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          pause
        end
      end

      def form_wait = FORM_WAIT
      def confirm_wait = CONFIRM_WAIT
      def pause = sleep(POLL)

      def captcha?(page)
        page.evaluate(CAPTCHA_JS, markers: CAPTCHA_MARKERS) ? true : false
      rescue *NAVIGATING_ERRORS
        false
      end

      def page_text(page)
        page.evaluate(TEXT_JS).to_s
      rescue *NAVIGATING_ERRORS
        ""
      end

      # A full-page JPEG, or just the viewport when the full page is over the proof size cap.
      def proof(page)
        bytes = page.screenshot(format: "jpeg", quality: 60, full: true, encoding: :binary)
        bytes = page.screenshot(format: "jpeg", quality: 60, full: false, encoding: :binary) if bytes.bytesize > Document::MAX_BYTES["proof"]
        { proof_bytes: bytes, proof_type: "image/jpeg", url: page.current_url }
      end

      def fallback(code) = Result.fallback(code)

      def form_selector = "form"
      def submit_selector = 'form button[type="submit"], form input[type="submit"]'
      def file_selector(question) = %(input[type="file"][name="#{css(question["id"])}"], input[type="file"][id="#{css(question["id"])}"])
      def field_selector(question) = %([name="#{css(question["id"])}"])

      # The page field a required input stands for: its name by default.
      def field_key(field) = field["name"].presence || field["id"]
      def field_key_for(question) = question["id"].to_s
      def normalize_key(key) = key.to_s.sub(/\[\]\z/, "").presence

      def css(value) = value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }

      def form_url
        raise NotImplementedError
      end

      def confirmed?(_page)
        raise NotImplementedError
      end
    end
  end
end
