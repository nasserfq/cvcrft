module JobApplications
  module Fetchers
    # Workday's career-site JSON (the "cxs" endpoint its own pages call).
    class Workday < Base
      PAGE = 20

      def call
        raise FetchError, "workday/#{employer.identifier}: host and site are required" if employer.host.blank? || employer.site.blank?

        url = "https://#{employer.host}/wday/cxs/#{employer.identifier}/#{employer.site}/jobs"
        jobs = []
        offset = 0
        MAX_PAGES.times do
          data = http_post(url, { limit: PAGE, offset:, searchText: "" })
          page = Array(data["jobPostings"])
          jobs.concat(page)
          offset += PAGE
          break if page.empty? || offset >= data["total"].to_i
        end
        gulf(jobs.map { |job| posting(job) })
      end

      private

      def posting(job)
        url = "https://#{employer.host}/en-US/#{employer.site}#{job['externalPath']}"
        Posting.new(
          external_id: (Array(job["bulletFields"]).first.presence || job["externalPath"]).to_s,
          title: job["title"],
          location: job["locationsText"],
          url:,
          apply_url: url,
          posted_at: posted_on(job["postedOn"])
        )
      end

      # "Posted Today", "Posted Yesterday", "Posted 3 Days Ago", "Posted 30+ Days Ago".
      def posted_on(text)
        case text.to_s
        when /today/i then Time.current.beginning_of_day
        when /yesterday/i then 1.day.ago.beginning_of_day
        when /(\d+)\+?\s+days?\s+ago/i then Regexp.last_match(1).to_i.days.ago.beginning_of_day
        end
      end
    end
  end
end
