module JobApplications
  module Fetchers
    # https://developers.ashbyhq.com/docs/public-job-posting-api
    class Ashby < Base
      def call
        data = http_get("https://api.ashbyhq.com/posting-api/job-board/#{CGI.escape(employer.identifier)}?includeCompensation=false")
        jobs = Array(data["jobs"]).reject { |job| job["isListed"] == false }
        gulf(jobs.map do |job|
          Posting.new(
            external_id: job["id"].to_s,
            title: job["title"],
            location: job["location"],
            country: job.dig("address", "postalAddress", "addressCountry"),
            url: job["jobUrl"],
            apply_url: job["applyUrl"],
            description: plain(job["descriptionPlain"]),
            posted_at: time(job["publishedAt"])
          )
        end)
      end
    end
  end
end
