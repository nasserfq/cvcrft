require "test_helper"

class JobApplications::PreferencesControllerTest < ActionDispatch::IntegrationTest
  # config.active_job.queue_adapter is :sidekiq in every env.
  def queue_adapter_for_test = ActiveJob::QueueAdapters::TestAdapter.new

  setup do
    @user = users(:one)
    sign_in @user
    ENV["SEERA_APPLY_TESTERS"] = @user.email
    AiCircuit.stubs(:busy?).returns(false)
  end

  teardown { ENV.delete("SEERA_APPLY_TESTERS") }

  def save(titles: "Product Manager، Data Analyst\nProduct Manager", cities: [ "", "riyadh", "remote" ])
    patch my_jobs_preferences_url(locale: "en"), params: { preference: { titles:, cities: } }
  end

  test "saves titles and cities and scores them for this user right away" do
    assert_enqueued_with(job: JobApplications::MatchJob, args: [ @user.id ]) { save }

    assert_redirected_to my_jobs_root_path
    assert_equal I18n.t("seera_apply.flash.saved", locale: :en), flash[:notice]
    preference = JobApplications::Preference.find_by!(user: @user)
    assert_equal [ "Product Manager", "Data Analyst" ], preference.titles
    assert_equal %w[riyadh remote], preference.cities
  end

  test "saving the same choices again does not rescore" do
    save
    assert_no_enqueued_jobs(only: JobApplications::MatchJob) { save }
  end

  test "an unknown city is rejected" do
    assert_no_enqueued_jobs { save(cities: [ "riyadh", "dubai" ]) }

    assert_redirected_to my_jobs_root_path
    assert_match "Riyadh", flash[:alert]
    assert_nil JobApplications::Preference.find_by(user: @user)
  end

  test "keeps at most ten titles" do
    save(titles: Array.new(12) { |i| "Title #{i}" }.join(","))

    assert_equal 10, JobApplications::Preference.find_by!(user: @user).titles.size
  end

  test "does not enqueue while the AI is busy" do
    AiCircuit.stubs(:busy?).returns(true)

    assert_no_enqueued_jobs { save }
    assert JobApplications::Preference.find_by!(user: @user).ready?
  end

  test "is hidden when Seera Apply is off" do
    ENV.delete("SEERA_APPLY_TESTERS")

    save
    assert_response :not_found
    assert_nil JobApplications::Preference.find_by(user: @user)
  end
end
