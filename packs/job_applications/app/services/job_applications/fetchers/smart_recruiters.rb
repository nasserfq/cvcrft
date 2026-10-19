module JobApplications
  module Fetchers
    # https://developers.smartrecruiters.com/docs/posting-api
    class SmartRecruiters < Base
      PAGE = 100

      def call
        id = CGI.escape(employer.identifier)
        jobs = []
        offset = 0
        MAX_PAGES.times do
          data = http_get("https://api.smartrecruiters.com/v1/companies/#{id}/postings?limit=#{PAGE}&offset=#{offset}")
          page = Array(data["content"])
          jobs.concat(page)
          offset += PAGE
          break if page.empty? || offset >= data["totalFound"].to_i
        end
        gulf(jobs.map { |job| posting(job) })
      end

      private

      def posting(job)
        url = "https://jobs.smartrecruiters.com/#{employer.identifier}/#{job['id']}"
        location = job["location"] || {}
        Posting.new(
          external_id: job["id"].to_s,
          title: job["name"],
          location: [ location["city"], location["region"], location["country"] ].compact_blank.join(", "),
          country: location["country"],
          url:,
          apply_url: url,
          posted_at: time(job["releasedDate"])
        )
      end
    end
  end
end
