require "test_helper"
require_relative "../../support/seera_apply_helper"

class JobApplications::FetchPostingsJobTest < ActiveJob::TestCase
  include SeeraApplyHelper

  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    ENV["SEERA_APPLY_TESTERS"] = users(:one).email
    JobApplications::EmployerSeeder.stubs(:call).returns({ created: 0, updated: 0, deactivated: 0, invalid: [] })
    @employer = create_employer(identifier: "acme")
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  def stub_greenhouse(data = ats_fixture("greenhouse"))
    JobApplications::Fetchers::Greenhouse.any_instance.stubs(:http_get).returns(data)
  end

  test "does nothing while the gate is off" do
    ENV.delete("SEERA_APPLY_TESTERS")
    JobApplications::EmployerSeeder.expects(:call).never
    JobApplications::Fetchers::Greenhouse.any_instance.expects(:http_get).never

    assert_no_enqueued_jobs { JobApplications::FetchPostingsJob.perform_now }
  end

  test "re-seeds employers, upserts postings with their city and enqueues matching" do
    JobApplications::EmployerSeeder.expects(:call).returns({ invalid: [] })
    stub_greenhouse

    assert_enqueued_with(job: JobApplications::MatchJob, args: []) { JobApplications::FetchPostingsJob.perform_now }

    postings = @employer.postings.order(:external_id)
    assert_nil @employer.reload.last_error
    assert_equal %w[101 103], postings.map(&:external_id)
    assert_equal [ "riyadh", nil ], postings.map(&:city)
    assert_equal [ "SA", "AE" ], postings.map(&:country)
    assert_not_nil @employer.reload.last_fetched_at
  end

  test "a second run updates in place and closes postings the feed dropped" do
    stub_greenhouse
    JobApplications::FetchPostingsJob.perform_now
    data = ats_fixture("greenhouse")
    data["jobs"] = data["jobs"].first(1).map { |job| job.merge("title" => "Product Manager") }
    JobApplications::Fetchers::Greenhouse.any_instance.stubs(:http_get).returns(data)

    JobApplications::FetchPostingsJob.perform_now

    assert_equal 2, @employer.postings.count
    assert_equal [ "101" ], @employer.postings.open.pluck(:external_id)
    assert_equal "Product Manager", @employer.postings.find_by!(external_id: "101").title
  end

  test "one failing employer records its error and the others still fetch" do
    broken = create_employer(ats: "lever", identifier: "broken")
    JobApplications::Fetchers::Lever.any_instance.stubs(:http_get).raises(JobApplications::Fetchers::FetchError, "HTTP 500")
    stub_greenhouse

    JobApplications::FetchPostingsJob.perform_now

    assert_match "HTTP 500", broken.reload.last_error
    assert_equal 2, @employer.postings.count
  end

  test "deletes long-closed postings with their matches and old AI counters" do
    old = create_posting(@employer, closed_at: 91.days.ago)
    match = create_match(users(:one), posting: old)
    JobApplications::AiUsage.create!(user: users(:one), day: 31.days.ago.to_date, scores: 3)
    JobApplications::AiUsage.create!(user: users(:one), day: Date.current, scores: 1)
    stub_greenhouse

    JobApplications::FetchPostingsJob.perform_now

    assert_not JobApplications::Posting.exists?(old.id)
    assert_not JobApplications::Match.exists?(match.id)
    assert_equal [ Date.current ], JobApplications::AiUsage.where(user: users(:one)).pluck(:day)
  end
end
