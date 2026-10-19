module JobApplications
  module Fetchers
    # Workable's public widget feed lists every job with its locations. When it
    # fails, the v3 job list that apply.workable.com itself calls is tried.
    class Workable < Base
      def call
        gulf(widget_jobs)
      rescue FetchError => e
        Rails.logger.info("[auto_apply] workable widget failed for #{employer.identifier}, trying v3: #{e.message}")
        gulf(v3_jobs)
      end

      private

      def widget_jobs
        data = http_get("https://apply.workable.com/api/v1/widget/accounts/#{CGI.escape(employer.identifier)}?details=true")
        Array(data["jobs"]).map do |job|
          shortcode = job["shortcode"].to_s
          url = job["url"].presence || job_url(shortcode)
          # A job in several places is kept once, at its first Gulf location.
          places = Array(job["locations"]).reject { |l| l["hidden"] }.presence || [ job ]
          place = places.find { |l| GulfLocation.country_for(location_text(l), l["countryCode"] || l["country"]) } || places.first
          Posting.new(
            external_id: shortcode,
            title: job["title"],
            location: location_text(place),
            country: place["countryCode"] || place["country"],
            url:,
            apply_url: job["application_url"].presence || "#{job_url(shortcode)}apply/",
            description: html_to_text(job["description"]),
            posted_at: time(job["published_on"] || job["created_at"])
          )
        end
      end

      # No descriptions in this list, so the matcher uses the title.
      def v3_jobs
        url = "https://apply.workable.com/api/v3/accounts/#{CGI.escape(employer.identifier)}/jobs"
        body = { query: "", location: [], department: [], worktype: [], remote: [] }
        jobs = []
        MAX_PAGES.times do
          data = http_post(url, body)
          jobs.concat(Array(data["results"]))
          break if data["nextPage"].blank?

          body = body.merge(token: data["nextPage"])
        end
        jobs.map do |job|
          location = job["location"] || {}
          Posting.new(
            external_id: job["shortcode"].to_s,
            title: job["title"],
            location: location_text(location),
            country: location["countryCode"] || location["country"],
            url: job_url(job["shortcode"]),
            apply_url: "#{job_url(job['shortcode'])}apply/",
            posted_at: time(job["published"])
          )
        end
      end

      def job_url(shortcode) = "https://apply.workable.com/#{employer.identifier}/j/#{shortcode}/"

      def location_text(place)
        [ place["city"], place["region"] || place["state"], place["country"] ].compact_blank.uniq.join(", ")
      end
    end
  end
end
