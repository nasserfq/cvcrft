require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "activestorage/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/railtie"
# require "action_text/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require_relative "../lib/trailing_slash_redirect"

module Cvcraft
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Feature modules live in packs/<name>/app, laid out like app/. Each one
    # is added to the same load paths as app/, so class names stay global
    # (packs/accounts/app/models/user.rb is still User). See packs/README.md.
    Dir[root.join("packs/*")].sort.each do |pack|
      %w[app app/controllers app/helpers app/models app/mailers app/views].each do |path|
        paths[path] << File.join(pack, path)
      end
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments/, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure Sidekiq as the background job processor
    config.active_job.queue_adapter = :sidekiq

    # Session store is configured in config/initializers/session_store.rb

    # Fall back to :en when a key is missing in :ar. Rails' own validation
    # messages ("can't be blank" and friends) ship only for :en, so without
    # this an Arabic request renders "Translation missing: ar.activerecord..."
    # instead of an error message. Production already set this; test and
    # development did not, which is why the suite showed 48 of these.
    config.i18n.fallbacks = [ :en ]

    # Only the two languages the site is written in. Gems ship other locales
    # (fr, de...), and without this ?locale=fr rendered a third, half-English
    # copy of every page.
    config.i18n.available_locales = [ :ar, :en ]

    config.middleware.insert_before 0, TrailingSlashRedirect
  end
end
