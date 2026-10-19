module JobApplications
  module Fetchers
    # https://developers.greenhouse.io/job-board.html
    class Greenhouse < Base
      def call
        data = http_get("https://boards-api.greenhouse.io/v1/boards/#{CGI.escape(employer.identifier)}/jobs?content=true")
        gulf(Array(data["jobs"]).map do |job|
          Posting.new(
            external_id: job["id"].to_s,
            title: job["title"],
            location: job.dig("location", "name"),
            url: job["absolute_url"],
            apply_url: job["absolute_url"],
            description: html_to_text(CGI.unescapeHTML(job["content"].to_s)),
            posted_at: time(job["updated_at"])
          )
        end)
      end
    end
  end
end
