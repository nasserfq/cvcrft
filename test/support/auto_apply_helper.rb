# Builders shared by the auto-apply (packs/job_applications) tests.
module AutoApplyHelper
  def ats_fixture(name)
    JSON.parse(file_fixture("ats/#{name}.json").read)
  end

  def create_employer(attrs = {})
    JobApplications::Employer.create!({ name: "Acme", ats: "greenhouse", identifier: "acme-#{SecureRandom.hex(3)}", country: "SA" }.merge(attrs))
  end

  def create_posting(employer = create_employer, attrs = {})
    id = SecureRandom.hex(4)
    JobApplications::Posting.create!({
      employer:, external_id: id, title: "Product Manager", location: "Riyadh", country: "SA",
      url: "https://job-boards.greenhouse.io/acme/jobs/#{id}", apply_url: "https://job-boards.greenhouse.io/acme/jobs/#{id}",
      description: "Own the roadmap.", posted_at: 1.day.ago, fetched_at: Time.current
    }.merge(attrs))
  end

  def consent!(user, attrs = {})
    JobApplications::Preference.create!({
      user:, titles: [ "Product Manager" ], countries: [ "SA" ],
      consent_accepted_at: Time.current, consent_version: JobApplications::CONSENT_VERSION
    }.merge(attrs))
  end

  def create_application(user, attrs = {})
    JobApplications::Application.create!({ user:, posting: create_posting, status: "approved", score: 8 }.merge(attrs))
  end

  def finished_resume(user, attrs = {})
    create_test_resume(user, { complete_name: "Sara Ali Hassan", email: "sara@example.com", phone_number: "0500000000",
                               city: "Riyadh", country: "Saudi Arabia", professional_summary: "Product manager.", is_draft: false }.merge(attrs))
  end

  def with_auto_apply_for(user)
    ENV["AUTO_APPLY_TESTERS"] = user.email
    yield
  ensure
    ENV.delete("AUTO_APPLY_TESTERS")
  end
end
