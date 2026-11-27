namespace :job_applications do
  desc "Load packs/job_applications/config/employers.yml into apply_employers"
  task seed_employers: :environment do
    result = JobApplications::EmployerSeeder.call
    puts "Employers: #{result[:created]} created, #{result[:updated]} updated, #{result[:deactivated]} deactivated."
    result[:invalid].each { |line| puts "  skipped #{line}" }
  end

  desc "Fetch postings from every active employer and match testers (needs SEERA_APPLY_ENABLED or SEERA_APPLY_TESTERS)"
  task fetch: :environment do
    abort "Set SEERA_APPLY_ENABLED=true or SEERA_APPLY_TESTERS to fetch." unless JobApplications.enabled_anywhere?

    JobApplications::FetchPostingsJob.perform_now
    puts "Fetched. Postings open: #{JobApplications::Posting.open.count}."
  end
end
