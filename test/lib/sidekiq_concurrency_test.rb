require "test_helper"

# Sidekiq's thread count has one source, config/initializers/sidekiq.rb, and the
# DB pool is sized from it.
class SidekiqConcurrencyTest < ActiveSupport::TestCase
  test "config/sidekiq.yml sets no concurrency, which the initializer would override" do
    config = YAML.safe_load(ERB.new(Rails.root.join("config/sidekiq.yml").read).result, permitted_classes: [ Symbol ])

    assert_not config.key?(:concurrency)
    assert_not config.key?("concurrency")
  end

  test "the DB pool covers the bigger of Puma and Sidekiq threads plus 5 for CvAnalysisJob's part threads" do
    expected = [ Integer(ENV.fetch("RAILS_MAX_THREADS", 5)), Integer(ENV.fetch("SIDEKIQ_CONCURRENCY", 5)) ].max + 5

    assert_equal expected, ActiveRecord::Base.connection_pool.size
  end
end
