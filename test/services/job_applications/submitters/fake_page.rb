# A stand-in for a Ferrum::Page, used by the submitter tests. It records what
# the submitter does (log) and plays back what the page "shows".
module SubmitterFakes
  Base = JobApplications::Submitters::Base

  class FakeNode
    attr_reader :selector

    def initialize(page, selector)
      @page = page
      @selector = selector
    end

    def tag_name = @page.tags.fetch(@selector, "input")
    def attribute(name) = name == "type" ? @page.input_types[@selector] : nil
    def focus = self
    def execute(_js, value:) = @page.log << [ :set, @selector, value ]
    def select(value, by:) = @page.log << [ :select, @selector, value, by ]
    def type(*keys) = @page.log << [ :type, @selector, *keys ]
    def select_file(path) = @page.log << [ :file, @selector, File.basename(path), File.binread(path) ]

    def click
      @page.log << [ :click, @selector ]
      @page.clicked!(@selector)
    end
  end

  class FakePage
    attr_reader :log, :tags, :input_types
    attr_accessor :current_url

    # required: [{"id", "name"}] the page marks required. missing: selectors
    # not on the page. after_submit: {url:, text:, captcha:, shows: [selectors]}
    # once Submit is clicked; the `shows` selectors are missing until then.
    def initialize(required: [], captcha: false, missing: [], tags: {}, input_types: {}, after_submit: {}, on_go_to: nil, on_click: nil)
      @required = required
      @captcha = captcha
      @missing = missing + Array(after_submit[:shows])
      @tags = tags
      @input_types = input_types
      @after_submit = after_submit
      @on_go_to = on_go_to
      @on_click = on_click
      @text = ""
      @log = []
    end

    def go_to(url)
      @on_go_to&.call
      @log << [ :go_to, url ]
      @current_url = url
    end

    def at_css(selector)
      FakeNode.new(self, selector) unless @missing.include?(selector)
    end

    def evaluate(js, **args)
      case js
      when Base::REQUIRED_FIELDS_JS then @required
      when Base::CAPTCHA_JS then @captcha
      when Base::TEXT_JS then @text
      when Base::CHECK_JS
        @log << [ :check, args[:key], args[:labels] ]
        1
      else raise "unexpected script"
      end
    end

    def screenshot(**options)
      @log << [ :screenshot, options ]
      "jpeg-bytes"
    end

    def clicked!(selector)
      @on_click&.call(selector)
      return unless selector.include?("submit")

      @current_url = @after_submit[:url] if @after_submit[:url]
      @text = @after_submit[:text].to_s
      @captcha = @after_submit[:captcha] if @after_submit.key?(:captcha)
      @missing -= Array(@after_submit[:shows])
    end

    def logged(kind) = @log.select { |entry| entry.first == kind }
  end

  # Browser.open that hands over the fake page.
  class FakeBrowser
    attr_reader :allow

    def initialize(page)
      @page = page
    end

    def open(allow:)
      @allow = allow
      yield @page
    end
  end

  # A sending application with the given questions and answers.
  def sending_application(ats:, questions:, answers:, posting_attrs: {})
    employer = JobApplications::Employer.find_by(ats:, identifier: "acme") || create_employer(ats:, identifier: "acme")
    app = create_application(@user, posting: create_posting(employer, posting_attrs), status: "sending", questions:, answers:,
                                    claimed_at: Time.current, attempts: 1)
    add_cv_pdf(app)
    app
  end

  def submitter_for(app, page)
    klass = "JobApplications::Submitters::#{app.posting.employer.ats.classify}".constantize
    submitter = klass.new(app, cv_pdf: "%PDF-1.4 tailored")
    submitter.stubs(:browser).returns(FakeBrowser.new(page))
    submitter.stubs(:pause)
    submitter.stubs(:form_wait).returns(0)
    submitter.stubs(:confirm_wait).returns(0)
    submitter
  end
end
