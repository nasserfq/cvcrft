ENV["RAILS_ENV"] ||= "test"
# Admin HTTP Basic Auth credentials. Set before the app boots: with
# eager_load on (CI), Admin::ApplicationController reads them at load time,
# and a later assignment leaves it with the random fallback password.
ENV["ADMIN_USERNAME"] ||= "admin"
ENV["ADMIN_PASSWORD"] ||= "test-only-admin-password"
require_relative "../config/environment"
require "rails/test_help"
require "sidekiq/testing"

# Jobs enqueue to an array, not Redis. Without this, perform_async raises
# RedisClient::CannotConnectError, controllers swallow it in their rescue
# blocks, and the tests see a 422 instead of the real behaviour. CI has no
# redis service either (it is commented out in .github/workflows/ci.yml).
Sidekiq::Testing.fake!
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The AI jobs all call AiModel.complete, which returns a RubyLLM::Message.
    # Stub that seam rather than Net::HTTP — the transport belongs to the
    # client library, and mocking it breaks whenever the client changes.
    def stub_ai_response(content, tokens: 800)
      text = content.is_a?(String) ? content : content.to_json
      usage = Struct.new(:input, :output).new(tokens / 2, tokens - (tokens / 2))
      AiModel.stubs(:complete).returns(Struct.new(:content, :tokens).new(text, usage))
    end

    # RuntimeError by default: the hand-rolled client used to `raise "..."`,
    # and the job tests assert on that so the failure path stays covered.
    def stub_ai_failure(error = RuntimeError.new("API Error"))
      AiModel.stubs(:complete).raises(error)
    end

    # Add more helper methods to be used by all tests here...

    # Helper to check if a string contains Arabic characters
    def contains_arabic?(text)
      return false if text.nil?
      text.match?(/[\u0600-\u06FF]/)
    end

    # Helper to create a valid resume for testing
    def create_test_resume(user, attrs = {})
      Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)

      default_attrs = {
        user: user,
        complete_name: "Test User",
        email: "test-#{SecureRandom.hex(4)}@example.com",
        is_draft: false
      }

      Resume.create!(default_attrs.merge(attrs))
    end

    # Helper to create a valid cv_generation for testing
    def create_test_cv_generation(user, attrs = {})
      default_attrs = {
        user: user,
        job_description: "Looking for a software engineer with 5+ years of experience in web development.",
        ai_model: "gpt-4",
        status: "processing"
      }

      CvGeneration.create!(default_attrs.merge(attrs))
    end

    # Helper to create a valid ai_translation for testing
    def create_test_translation(user, attrs = {})
      default_attrs = {
        user: user,
        arabic_text: "نص عربي طويل بما يكفي للترجمة والاختبار",
        ai_model: "gpt-4",
        status: "pending"
      }

      AiTranslation.create!(default_attrs.merge(attrs))
    end

    # Helper to create a valid OTP for testing
    def create_test_otp(email, attrs = {})
      default_attrs = {
        email: email,
        otp_code: "123456",
        expires_at: 10.minutes.from_now,
        verified: false
      }

      OtpVerification.create!(default_attrs.merge(attrs))
    end

    # Stub PDF generation for all tests
    def stub_pdf_generation
      Resume.any_instance.stubs(:queue_pdf_generation).returns(nil)
    end

    # Assert that a model has specific errors
    def assert_has_errors(model, *attributes)
      model.valid?
      attributes.each do |attr|
        assert model.errors[attr].any?, "Expected errors on #{attr}, but got none"
      end
    end

    # Assert that a model is valid
    def assert_valid(model)
      assert model.valid?, "Expected model to be valid, but got errors: #{model.errors.full_messages.join(', ')}"
    end

    # Assert that a model is invalid
    def assert_invalid(model)
      assert_not model.valid?, "Expected model to be invalid"
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers

    # HTTP Basic Auth credentials for the admin panel. These must match what
    # Admin::ApplicationController reads, or any admin-route test gets the
    # random fallback password and 401s.
    BASIC_AUTH_USERNAME = ENV.fetch("ADMIN_USERNAME")
    BASIC_AUTH_PASSWORD = ENV.fetch("ADMIN_PASSWORD")

    # Helper to get HTTP Basic Auth header
    def basic_auth_header
      { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(BASIC_AUTH_USERNAME, BASIC_AUTH_PASSWORD) }
    end

    # Override request methods to include basic auth by default
    def get(path, **args)
      args[:headers] = (args[:headers] || {}).merge(basic_auth_header)
      super
    end

    def post(path, **args)
      args[:headers] = (args[:headers] || {}).merge(basic_auth_header)
      super
    end

    def patch(path, **args)
      args[:headers] = (args[:headers] || {}).merge(basic_auth_header)
      super
    end

    def put(path, **args)
      args[:headers] = (args[:headers] || {}).merge(basic_auth_header)
      super
    end

    def delete(path, **args)
      args[:headers] = (args[:headers] || {}).merge(basic_auth_header)
      super
    end

    # Helper to sign in a user for integration tests
    def sign_in_user(user)
      sign_in user
    end

    # Helper to assert JSON response
    def assert_json_response
      assert_equal "application/json", response.media_type
    end

    # Helper to parse JSON response
    def json_response
      JSON.parse(response.body)
    end
  end
end
