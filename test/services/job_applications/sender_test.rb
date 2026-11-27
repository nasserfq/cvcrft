require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::SenderTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  Result = JobApplications::Submitters::Result

  # Stands in for a submitter; Unit 3 and 4 build the real ones.
  class FakeSubmitter
    class << self
      attr_accessor :behaviour, :calls
    end

    def self.questions(_posting) = []

    def initialize(application, cv_pdf:)
      @application = application
      @cv_pdf = cv_pdf
    end

    def call
      self.class.calls += 1
      self.class.behaviour.call(@application)
    end
  end

  setup do
    @user = users(:one)
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @profile = create_profile(@user)
    FakeSubmitter.calls = 0
    FakeSubmitter.behaviour = lambda do |app|
      app.mark_submit_clicked!
      Result.sent(proof_bytes: "jpeg-bytes", proof_type: "image/jpeg", url: "https://x/confirmation", text: "Thank you")
    end
    JobApplications::Submitters.stubs(:for).returns(FakeSubmitter)
  end

  teardown { ENV.delete("BILLING_ENABLED") }

  def queued(attrs = {})
    create_application(@user, { status: "queued" }.merge(attrs)).tap { |app| add_cv_pdf(app) }
  end

  def send!(app) = JobApplications::Sender.new(app).tap(&:call)

  test "a confirmed send is sent, keeps its proof and is free for the first three" do
    app = queued
    send!(app)
    app.reload

    assert_equal [ "sent", "free", 1 ], [ app.status, app.charge, app.attempts ]
    assert app.sent_at
    assert_equal "https://x/confirmation", app.confirmation["url"]
    assert_equal [ "image/jpeg", "jpeg-bytes" ], [ app.proof.content_type, app.proof.data ]
    assert_equal 1, @user.reload.job_applications_count
    assert_equal "sent", JobApplications::Disclosure.find_by!(application_id: app.id).outcome
  end

  test "past the free three a send costs 5 credits, charged once for the same key" do
    ENV["BILLING_ENABLED"] = "true"
    @user.update_column(:job_applications_count, 3)
    balance = Billing::Credits.balance(@user)
    app = queued

    send!(app)
    assert_nil JobApplications::Sender.new(app.reload).charge!
    assert_equal :credit, Billing::UsageGate.allow!(@user, :job_application, key: "job_application:#{app.id}")

    assert_equal "credit", app.reload.charge
    assert_equal balance - 5, Billing::Credits.balance(@user)
    assert_equal 1, CreditLedgerEntry.where(reason: "overage_job_application").count
    assert_equal 3, @user.reload.job_applications_count
  end

  test "with billing off, past three it holds as no_credits" do
    @user.update_column(:job_applications_count, 3)
    app = queued

    send!(app)

    assert_equal [ "queued", "no_credits" ], app.reload.values_at(:status, :hold)
    assert_equal 0, FakeSubmitter.calls
  end

  test "paused holds automatic rows but an approved row still goes" do
    @profile.pause!
    held = queued
    send!(held)
    assert_equal [ "queued", "paused" ], held.reload.values_at(:status, :hold)

    approved = queued(approved_at: Time.current)
    send!(approved)
    assert_equal "sent", approved.reload.status
  end

  test "withdrawn consent holds even an approved row" do
    @profile.turn_off!
    app = queued(approved_at: Time.current)

    send!(app)

    assert_equal [ "queued", "paused" ], app.reload.values_at(:status, :hold)
  end

  test "five sent or sending today in Riyadh time hold the next as daily_cap" do
    travel_to Time.find_zone("Asia/Riyadh").local(2026, 11, 28, 0, 30) do
      5.times { create_application(@user, status: "sent", claimed_at: Time.current, sent_at: Time.current) }
      create_application(@user, status: "sent", claimed_at: 1.hour.ago) # yesterday in Riyadh
      app = queued

      send!(app)

      assert_equal [ "queued", "daily_cap" ], app.reload.values_at(:status, :hold)
    end
  end

  test "a second row of the user already sending stays queued with no hold" do
    create_application(@user, status: "sending", claimed_at: Time.current)
    app = queued

    send!(app)

    assert_equal [ "queued", nil ], app.reload.values_at(:status, :hold)
    assert_equal 0, FakeSubmitter.calls
  end

  test "a closed posting falls back" do
    app = queued
    app.posting.update!(closed_at: Time.current)

    send!(app)

    assert_equal %w[failed_fallback closed], app.reload.values_at(:status, :error_code)
  end

  test "a fallback charges nothing and leaves the counter alone" do
    FakeSubmitter.behaviour = ->(_app) { Result.fallback("captcha") }
    app = queued

    send!(app)

    assert_equal [ "failed_fallback", "captcha", nil ], app.reload.values_at(:status, :error_code, :charge)
    assert_equal 0, @user.reload.job_applications_count
    assert_equal "fallback", JobApplications::Disclosure.find_by!(application_id: app.id).outcome
  end

  test "Retryable before the click goes back to queued, then times out once attempts are used up" do
    FakeSubmitter.behaviour = ->(_app) { raise JobApplications::Submitters::Retryable, "page timeout" }
    app = queued

    send!(app)
    assert_equal [ "queued", 1 ], app.reload.values_at(:status, :attempts)
    send!(app)
    send!(app)

    assert_equal [ "failed_fallback", "timeout", 3 ], app.reload.values_at(:status, :error_code, :attempts)
    assert_equal 3, JobApplications::Disclosure.where(application_id: app.id).count
    assert_equal 0, @user.reload.job_applications_count
  end

  test "an error after the click is unconfirmed, never retried and not charged" do
    FakeSubmitter.behaviour = lambda do |app|
      app.mark_submit_clicked!
      raise IOError, "browser died"
    end
    Sentry.expects(:capture_exception).once
    app = queued

    send!(app)

    assert_equal [ "failed_fallback", "unconfirmed", nil ], app.reload.values_at(:status, :error_code, :charge)
    assert_equal 0, @user.reload.job_applications_count
  end

  test "an error before the click is send_error" do
    FakeSubmitter.behaviour = ->(_app) { raise IOError, "bug" }
    Sentry.stubs(:capture_exception)
    app = queued

    send!(app)

    assert_equal %w[failed_fallback send_error], app.reload.values_at(:status, :error_code)
  end

  test "no submitter for the channel falls back as unsupported" do
    JobApplications::Submitters.stubs(:for).returns(nil)
    app = queued

    send!(app)

    assert_equal %w[failed_fallback unsupported], app.reload.values_at(:status, :error_code)
  end

  test "writes one disclosure per attempt with the employer and data categories" do
    app = queued

    send!(app)

    disclosure = JobApplications::Disclosure.sole
    assert_equal [ @user.id, app.id, "Acme", "browser", "job-boards.greenhouse.io", JobApplications::CONSENT_VERSION ],
                 disclosure.values_at(:user_id, :application_id, :employer_name, :channel, :recipient, :consent_version)
    assert_includes disclosure.data_categories, "cv"
    assert_not_includes disclosure.data_categories, "expected_salary"
  end

  test "does nothing for a row that is not queued" do
    app = create_application(@user, status: "needs_approval")

    send!(app)

    assert_equal "needs_approval", app.reload.status
    assert_equal 0, JobApplications::Disclosure.count
  end

  test "a blocked charge after a confirmed send is stored as uncollected" do
    app = create_application(@user, status: "sent", sent_at: Time.current)
    Billing::UsageGate.stubs(:allow!).returns(:blocked)
    Sentry.expects(:capture_message).once

    assert_equal :blocked, JobApplications::Sender.new(app).charge!
    assert_equal "uncollected", app.reload.charge
  end

  test "an email row with no address falls back before any disclosure" do
    app = queued(channel: "email")
    Sentry.expects(:capture_exception).never

    send!(app)

    assert_equal %w[failed_fallback unsupported], app.reload.values_at(:status, :error_code)
    assert_equal 0, FakeSubmitter.calls
    assert_equal 0, JobApplications::Disclosure.count
  end

  test "a missing CV falls back as prepare_failed before any disclosure" do
    app = create_application(@user, status: "queued")

    send!(app)

    assert_equal %w[failed_fallback prepare_failed], app.reload.values_at(:status, :error_code)
    assert_equal 0, JobApplications::Disclosure.count
  end

  test "a charge that raises after a confirmed send keeps the row and its disclosure sent" do
    Billing::UsageGate.stubs(:allow!).raises(ActiveRecord::Deadlocked)
    Sentry.stubs(:capture_exception)
    app = queued

    send!(app)

    assert_equal [ "sent", nil ], app.reload.values_at(:status, :charge)
    assert_equal "sent", JobApplications::Disclosure.find_by!(application_id: app.id).outcome
  end

  test "a dry-run fallback keeps its screenshot as the proof" do
    FakeSubmitter.behaviour = ->(_app) { Result.fallback("dry_run", proof_bytes: "jpeg", proof_type: "image/jpeg") }
    app = queued

    send!(app)

    assert_equal %w[failed_fallback dry_run], app.reload.values_at(:status, :error_code)
    assert_equal "jpeg", app.proof.data
  end
end

# Real threads, each with its own connection, so the profile lock is exercised.
class JobApplications::SenderRaceTest < ActiveSupport::TestCase
  include SeeraApplyHelper

  self.use_transactional_tests = false

  setup do
    CouponRedemptionStore.stubs(:redeemed_codes_for).returns([])
    @user = User.create!(email: "apply-race-#{SecureRandom.hex(4)}@example.com", name: "Race User", password: "password123")
    create_profile(@user)
    @posting = create_posting
    @app = create_application(@user, posting: @posting, status: "needs_approval")
    add_cv_pdf(@app)
    @calls = Concurrent::AtomicFixnum.new
    calls = @calls
    submitter = Class.new do
      define_method(:initialize) { |application, cv_pdf:| @application = application }
      define_method(:call) do
        calls.increment
        sleep 0.05
        @application.mark_submit_clicked!
        JobApplications::Submitters::Result.sent(url: "https://x/confirmation")
      end
    end
    JobApplications::Submitters.stubs(:for).returns(submitter)
    JobApplications::BrowserSlot.stubs(:acquire).returns("token")
    JobApplications::BrowserSlot.stubs(:release)
  end

  teardown do
    @user&.destroy
    @posting&.employer&.destroy
    ENV.delete("SEERA_APPLY_TESTERS")
  end

  test "approve! and DispatchJob on the same row submit exactly once" do
    ENV["SEERA_APPLY_TESTERS"] = @user.email
    enqueued = []
    JobApplications::SendJob.stubs(:perform_later).with { |id| enqueued << id }

    assert @app.approve!
    JobApplications::DispatchJob.perform_now
    assert_equal [ @app.id, @app.id ], enqueued

    enqueued.map do |id|
      Thread.new { ActiveRecord::Base.connection_pool.with_connection { JobApplications::SendJob.perform_now(id) } }
    end.each(&:join)

    assert_equal 1, @calls.value
    assert_equal [ "sent", 1 ], @app.reload.values_at(:status, :attempts)
    assert_equal 1, JobApplications::Disclosure.where(application_id: @app.id).count
  end
end
