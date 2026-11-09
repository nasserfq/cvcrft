require "test_helper"

class DeadJobReporterTest < ActiveSupport::TestCase
  test "reports the wrapped job class, queue and error class, never the args or error message" do
    job = {
      "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "CvAnalysisJob", "queue" => "default",
      "args" => [ { "arguments" => [ 42, "someone@example.com" ] } ]
    }
    sent = nil
    Sentry.expects(:capture_message).with { |message, **options| sent = [ message, options ] }

    DeadJobReporter.call(job, RuntimeError.new("someone@example.com broke it"))

    message, options = sent
    assert_equal "Sidekiq job died: CvAnalysisJob", message
    assert_equal :error, options[:level]
    assert_equal({ job_class: "CvAnalysisJob", queue: "default", error_class: "RuntimeError" }, options[:tags])
    assert_no_match(/example\.com|42/, [ message, options ].inspect)
  end

  test "a plain Sidekiq job is named by its class" do
    Sentry.expects(:capture_message).with { |message, **| message == "Sidekiq job died: AiTranslationJob" }

    DeadJobReporter.call({ "class" => "AiTranslationJob", "queue" => "ai_translations" }, ArgumentError.new)
  end

  test "a Sentry failure never breaks Sidekiq's death handling" do
    Sentry.stubs(:capture_message).raises(StandardError)

    assert_nothing_raised { DeadJobReporter.call({ "class" => "X" }, RuntimeError.new) }
  end
end
