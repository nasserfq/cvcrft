require "ferrum"
require "fileutils"
require "tmpdir"
require "timeout"

module JobApplications
  module Submitters
    # One headless Chromium for one application, closed afterwards. Started
    # through bin/chromium-clean (env -i), so the browser never sees the app's
    # secrets, with a fresh profile and requests limited to the ATS's hosts.
    module Browser
      DEFAULT_PATH = "/rails/bin/chromium-clean".freeze
      RUN_LIMIT = 120 # seconds for the whole run, browser start included
      # Schemes that never leave the machine.
      LOCAL = [ /\A(?:data|blob|about):/ ].freeze

      module_function

      # Yields a Ferrum::Page whose requests may only go to `allow` (Regexps).
      # Raises Timeout::Error when the run takes longer than RUN_LIMIT.
      def open(allow:)
        dir = Dir.mktmpdir("seera-apply-chrome-")
        browser = nil
        Timeout.timeout(RUN_LIMIT) do
          browser = Ferrum::Browser.new(options(dir))
          page = browser.create_page
          page.network.allowlist = LOCAL + Array(allow)
          yield page
        end
      ensure
        quit(browser)
        FileUtils.rm_rf(dir) if dir
      end

      def options(user_data_dir)
        path = ENV.fetch("CHROMIUM_PATH", DEFAULT_PATH)
        {
          # Missing in dev and CI: Ferrum then finds Chrome on its own.
          browser_path: (path if File.executable?(path)),
          headless: true,
          timeout: 30,
          process_timeout: 20,
          window_size: [ 1280, 2000 ],
          browser_options: {
            "headless" => "new",
            "user-data-dir" => user_data_dir,
            "no-sandbox" => nil,
            "disable-dev-shm-usage" => nil,
            "disable-gpu" => nil
          }
        }
      end

      # Turns HOSTS entries into request patterns. "greenhouse.io" allows the
      # host and its subdomains over https; "www.google.com/recaptcha/" allows
      # that path prefix only; a Regexp is used as given.
      def allowlist(hosts)
        hosts.map do |entry|
          next entry if entry.is_a?(Regexp)

          if entry.include?("/")
            %r{\Ahttps://#{Regexp.escape(entry)}}
          else
            %r{\Ahttps://(?:[a-z0-9-]+\.)*#{Regexp.escape(entry)}(?::\d+)?(?:[/?#]|\z)}
          end
        end
      end

      def quit(browser)
        browser&.quit
      rescue StandardError => e
        Rails.logger.warn("[seera_apply] chromium quit failed: #{e.class}: #{e.message}")
      end
      private_class_method :quit
    end
  end
end
