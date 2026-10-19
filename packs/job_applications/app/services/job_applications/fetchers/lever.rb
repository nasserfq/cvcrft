module JobApplications
  module Fetchers
    # https://github.com/lever/postings-api
    class Lever < Base
      def call
        data = http_get("https://api.lever.co/v0/postings/#{CGI.escape(employer.site.presence || employer.identifier)}?mode=json")
        gulf(Array(data).map do |job|
          Posting.new(
            external_id: job["id"].to_s,
            title: job["text"],
            location: job.dig("categories", "location"),
            country: job["country"],
            url: job["hostedUrl"],
            apply_url: job["applyUrl"],
            description: plain(job["descriptionPlain"]),
            posted_at: time(job["createdAt"])
          )
        end)
      end
    end
  end
end
