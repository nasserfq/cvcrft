module JobApplications
  module Fetchers
    # apply.workable.com's own job list; it has no descriptions, so the matcher uses the title.
    class Workable < Base
      def call
        url = "https://apply.workable.com/api/v3/accounts/#{CGI.escape(employer.identifier)}/jobs"
        body = { query: "", location: [], department: [], worktype: [], remote: [] }
        jobs = []
        MAX_PAGES.times do
          data = http_post(url, body)
          jobs.concat(Array(data["results"]))
          break if data["nextPage"].blank?

          body = body.merge(token: data["nextPage"])
        end
        gulf(jobs.map { |job| posting(job) })
      end

      private

      def posting(job)
        url = "https://apply.workable.com/#{employer.identifier}/j/#{job['shortcode']}/"
        location = job["location"] || {}
        Posting.new(
          external_id: job["shortcode"].to_s,
          title: job["title"],
          location: [ location["city"], location["country"] ].compact_blank.join(", "),
          country: location["countryCode"] || location["country"],
          url:,
          apply_url: "#{url}apply/",
          posted_at: time(job["published"])
        )
      end
    end
  end
end
