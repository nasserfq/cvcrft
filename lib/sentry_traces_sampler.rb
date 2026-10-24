# Decides which requests and jobs Sentry traces. Health checks and
# bin/load-test (oha) are skipped so they don't skew the speed numbers;
# everything else uses SENTRY_TRACES_SAMPLE_RATE (default: all of it).
module SentryTracesSampler
  SKIPPED_PATHS = %w[/up].freeze
  LOAD_TEST_AGENT = /\Aoha\//

  def self.call(context)
    return context[:parent_sampled] ? 1.0 : 0.0 unless context[:parent_sampled].nil?

    env = context[:env]
    return 0.0 if env && SKIPPED_PATHS.include?(env["PATH_INFO"])
    return 0.0 if env && env["HTTP_USER_AGENT"].to_s.match?(LOAD_TEST_AGENT)

    ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "1.0").to_f
  end
end
